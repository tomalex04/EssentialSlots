import os
import re
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from llama_cpp import Llama
from huggingface_hub import hf_hub_download
import numpy as np
import torch

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logging.getLogger('watchdog').setLevel(logging.WARNING)

# Load the dataset
dataset = []
LABS_DIRECTORY = '/home/tom/Desktop/lab_files/'  # Update this to the path of your labs directory

# Model configurations - using the direct repo IDs and filenames
EMBEDDING_MODEL = 'CompendiumLabs/bge-base-en-v1.5-gguf'
EMBEDDING_FILENAME = "bge-base-en-v1.5-f16.gguf"
LANGUAGE_MODEL = 'bartowski/Llama-3.2-1B-Instruct-GGUF'
LANGUAGE_FILENAME = "Llama-3.2-1B-Instruct-Q5_K_M.gguf"

# Vector database storage
VECTOR_DB = []

# Conversation history storage (for multi-turn conversations)
conversation_history = {}  # Will store history by session_id

def read_files_in_directory(directory):
    """Read all files in the specified directory and add their contents to the dataset."""
    logging.debug(f"Reading files from directory: {directory}")
    for root, dirs, files in os.walk(directory):
        logging.debug(f"Checking directory: {root}")
        for file in files:
            logging.debug(f"Found file: {file}")
            file_path = os.path.join(root, file)
            logging.debug(f"Processing file: {file_path}")
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if content.strip():  # Check if content is not empty
                        lab_name = os.path.basename(root)
                        dataset.append((lab_name, content))
                        logging.debug(f"Added file content from {file_path} to dataset")
                    else:
                        logging.debug(f"File {file_path} is empty")
            except Exception as e:
                logging.error(f"Failed to read file {file_path}: {e}")

def add_chunk_to_database(chunk, metadata):
    """Add a chunk of text and its embedding to the vector database."""
    # Get embedding using the initialized Llama model
    embedding = embedding_model.embed(chunk)
    VECTOR_DB.append((chunk, embedding, metadata))

def split_text_into_semantic_chunks(text):
    """Split text into semantically meaningful chunks that preserve natural context.
    
    This approach chunks text based on natural semantic boundaries:
    - Each question-answer pair is kept together
    - Paragraphs are kept intact when possible
    - Section headings are kept with their content
    - Bullet point lists are kept together
    """
    # First identify and keep Q&A pairs together
    qa_pattern = re.compile(r'(?:^|\n)(?:Q|Question)[\d\s:.]*([^\n]+)[\n\s]+((?:A|Answer)[\d\s:.]*[^\n]+(?:\n(?!\n*(?:Q|Question)[\d\s:.])[^\n]+)*)', re.IGNORECASE)
    
    # Also identify section headers to preserve structure
    section_pattern = re.compile(r'(?:^|\n)(#+\s+.+\n)(.+(?:\n(?!#+\s+).+)*)', re.DOTALL)
    
    # Find all matches of both patterns
    qa_matches = list(qa_pattern.finditer(text))
    section_matches = list(section_pattern.finditer(text))
    
    # If we have Q&A or section matches, use them to chunk
    if qa_matches or section_matches:
        chunks = []
        # Process Q&A pairs
        for match in qa_matches:
            qa_pair = match.group(0).strip()
            if qa_pair:
                chunks.append(qa_pair)
                
        # Process sections
        for match in section_matches:
            section = match.group(0).strip()
            # Don't include if it's just a heading with no content
            if len(section.split('\n')) > 1:
                chunks.append(section)
        
        # If we found structured content, return it
        if chunks:
            return chunks
    
    # For unstructured text, split by paragraphs first
    paragraphs = re.split(r'\n\s*\n', text)
    
    chunks = []
    for paragraph in paragraphs:
        paragraph = paragraph.strip()
        if not paragraph:
            continue
            
        # For longer paragraphs, split by sentences
        if len(paragraph) > 500:  # Character-based threshold instead of word count
            # Split the paragraph into sentences
            sentences = re.split(r'(?<=[.!?]) +', paragraph)
            if len(sentences) > 1:
                for sentence in sentences:
                    if sentence.strip():
                        chunks.append(sentence.strip())
            else:
                chunks.append(paragraph)
        else:
            # Keep shorter paragraphs intact
            chunks.append(paragraph)
    
    # Filter out empty chunks and duplicates while preserving order
    seen = set()
    filtered_chunks = []
    for chunk in chunks:
        if chunk and chunk not in seen:
            seen.add(chunk)
            filtered_chunks.append(chunk)
            
    return filtered_chunks

def cosine_similarity(a, b):
    """Calculate cosine similarity between two vectors."""
    dot_product = sum([x * y for x, y in zip(a, b)])
    norm_a = sum([x ** 2 for x in a]) ** 0.5
    norm_b = sum([x ** 2 for x in b]) ** 0.5
    return dot_product / (norm_a * norm_b)

def retrieve(query, top_n=5, threshold=0.65):
    """Retrieve the most relevant chunks for a given query."""
    # Get query embedding using the same Llama model
    query_embedding = embedding_model.embed(query)
    
    similarities = []
    for chunk, embedding, metadata in VECTOR_DB:
        similarity = cosine_similarity(query_embedding, embedding)
        # Only include results above threshold
        if similarity > threshold:
            similarities.append((chunk, similarity, metadata))
    similarities.sort(key=lambda x: x[1], reverse=True)
    
    logging.debug(f"Retrieved {len(similarities)} chunks above threshold {threshold} for query: '{query}'")
    for i, (chunk, similarity, metadata) in enumerate(similarities[:top_n]):
        logging.debug(f"Chunk {i+1}: {similarity:.4f} - {metadata['lab_name']}: {chunk[:100]}...")
    
    return similarities[:top_n]

def initialize_models():
    """Initialize and load models using llama-cpp-python."""
    global embedding_model, language_model
    
    # Download and get paths for models using hf_hub_download
    logging.debug(f"Initializing embedding model: {EMBEDDING_MODEL}/{EMBEDDING_FILENAME}")
    
    # Download models and get their paths using hf_hub_download
    embedding_model_path = hf_hub_download(
        repo_id=EMBEDDING_MODEL,
        filename=EMBEDDING_FILENAME,
        resume_download=True
    )
    logging.debug(f"Downloaded embedding model to: {embedding_model_path}")
    
    language_model_path = hf_hub_download(
        repo_id=LANGUAGE_MODEL,
        filename=LANGUAGE_FILENAME,
        resume_download=True
    )
    logging.debug(f"Downloaded language model to: {language_model_path}")
    
    # Initialize the embedding model
    embedding_model = Llama(
        model_path=embedding_model_path,
        n_ctx=512,  # Smaller context for embeddings
        embedding=True,  # Enable embeddings
        n_threads=4
    )
    logging.debug("Embedding model initialized")
    
    # Initialize the language model
    logging.debug(f"Initializing language model: {language_model_path}")
    language_model = Llama(
        model_path=language_model_path,
        n_ctx=2048,  # Context window size
        n_threads=8,
        n_batch=512,
        temperature=0.1,    # Reduced from 0.2 for more deterministic responses
        top_p=0.85,         # Reduced from 0.95 to constrain token selection
        repeat_penalty=1.2  # Increased from 1.1 to reduce repetition
    )
    
    logging.debug("Language model initialized successfully")

def rewrite_query(original_query, history=None, max_history=3):
    """Rewrite the user's original query to be more specific and retrieval-friendly."""
    # Direct handling for lab listing queries without involving the LLM
    if any(phrase in original_query.lower() for phrase in [
        "available labs", "which labs", "what labs", "list of labs", "labs available", "which are the available labs", 
        "what are the available labs", "list labs", "show labs", "show me the labs"
    ]):
        return "What labs are available in the system?"
    
    # Direct handling for follow-up queries that are about available labs
    if history and len(history) > 0:
        last_query, last_response = history[-1]
        if "I'm specialized in answering questions about labs" in last_response and any(phrase in original_query.lower() for phrase in [
            "that's exactly what i'm doing", "thats exactly what im doing", "that is what i'm asking",
            "that is what i am asking", "i am", "i did", "yes", "exactly"
        ]):
            return "What labs are available in the system?"
    
    # Handle simple greetings directly
    if original_query.lower().strip() in ["hey", "hi", "hello"]:
        return "This is a greeting. Respond with a friendly lab assistant introduction."
    
    # Build the prompt for query rewriting for more complex queries
    system_prompt = """You are an AI assistant that helps with lab-related questions.
    
    IMPORTANT RULES:
    1. For lab-related questions: Rewrite them to be fully specific and self-contained for accurate retrieval.
    2. For general greetings (like 'hi', 'hello', 'hey'): Rewrite as "This is a greeting. Respond with a friendly lab assistant introduction."
    3. For off-topic questions: Rewrite as "This is not a lab-related question. Clarify that you're a lab assistant."
    4. For ambiguous questions: Add context from conversation history if available.
    5. Always keep the rewritten query focused on retrieving lab information.
    6. For questions about available labs or which labs exist: Rewrite as "What labs are available in the system?"
    7. AVOID COMPLEX REWRITING - stay close to the original query whenever possible."""
    
    user_prompt = "Analyze and rewrite the following query according to the rules:"
    
    # Add conversation history context if available
    if history and len(history) > 0:
        history_context = "Previous conversation:\n"
        for i, (q, r) in enumerate(history[-max_history:]):
            history_context += f"User: {q}\nAssistant: {r}\n"
        user_prompt = f"{history_context}\n{user_prompt}"
    
    user_prompt += f"\n\nUser query: {original_query}\n\nRewritten query:"
    
    # Full prompt for the language model
    full_prompt = f"{system_prompt}\n\n{user_prompt}"
    
    # Generate text with improved parameters
    response = language_model(
        full_prompt, 
        max_tokens=256,
        echo=False,
        temperature=0.1,  # Very low temperature for consistent rewrites
        top_p=0.75        # Lower for more predictable outputs
    )
    
    # Extract the generated content
    rewritten_query = response['choices'][0]['text'].strip()
    logging.debug(f"Original query: {original_query}")
    logging.debug(f"Rewritten query: {rewritten_query}")
    
    return rewritten_query

def generate_answer(rewritten_query, retrieved_chunks):
    """Generate final answer using the rewritten query and retrieved chunks."""
    if not retrieved_chunks:
        return "I don't have specific information about that in my database. Could you ask about a specific lab or procedure?"
    
    # Build context from retrieved chunks
    context_parts = []
    for i, (chunk, similarity, metadata) in enumerate(retrieved_chunks):
        # Include similarity score and lab name for better context
        context_parts.append(f"[{i+1}] Lab: {metadata['lab_name']} (Relevance: {similarity:.2f})\n{chunk}")
    
    context = "\n\n".join(context_parts)
    
    # Improved system prompt with better handling for subjective queries
    system_prompt = """You are a helpful lab assistant that provides accurate information about laboratory facilities, procedures, and equipment.

STRICT GUIDELINES:
1. ONLY use the information provided in the context. Do not make up facts or details.
2. If the context doesn't have the answer, say: "I don't have specific information about that in my database."
3. If the context has partial information, provide what you have and acknowledge what's missing.
4. When asked about "which lab is good" or similar subjective queries:
   - DO NOT give opinions on which lab is "best" or "good"
   - Instead, provide an objective comparison of labs based on their features, equipment, and capabilities
   - List key features of each lab from the context
   - Use a structured format that makes it easy to compare labs
5. Format your answers with paragraph breaks for readability.
6. Always mention which lab you're referring to when providing information.
7. DO NOT hallucinate lab details, equipment, or procedures not mentioned in the context."""
    
    user_prompt = f"""CONTEXT:
{context}

USER QUESTION: {rewritten_query}

ANSWER:"""
    
    # Full prompt for the language model
    full_prompt = f"{system_prompt}\n\n{user_prompt}"
    
    # Generate text with better parameters
    response = language_model(
        full_prompt,
        max_tokens=512,
        echo=False,
        temperature=0.1,  # Keep very low for factual accuracy
        top_p=0.80,       # Reduce further for more focused responses
        repeat_penalty=1.2
    )
    
    # Extract the generated content
    answer = response['choices'][0]['text'].strip()
    
    # Post-process for enhanced subjective query handling
    if "which" in rewritten_query.lower() and "lab" in rewritten_query.lower() and ("good" in rewritten_query.lower() or "best" in rewritten_query.lower() or "better" in rewritten_query.lower()):
        # Get unique lab names from retrieved chunks
        lab_names = list(set(metadata['lab_name'] for _, _, metadata in retrieved_chunks))
        
        if len(lab_names) < 2:
            return "I don't have enough information to compare different labs. I can only provide details about specific labs if you ask about them directly."
            
        # Generate a structured comparison if we have multiple labs
        labs_info = {}
        for chunk, _, metadata in retrieved_chunks:
            lab_name = metadata['lab_name']
            if lab_name not in labs_info:
                labs_info[lab_name] = []
            labs_info[lab_name].append(chunk)
        
        # Create a structured comparison
        comparison = "Based on the information I have, here's an objective comparison of the labs:\n\n"
        
        for lab_name, chunks in labs_info.items():
            comparison += f"**{lab_name}**:\n"
            for chunk in chunks[:3]:  # Limit to first 3 chunks per lab to keep it manageable
                # Extract a short summary from each chunk (first 100 chars)
                summary = chunk[:100] + "..." if len(chunk) > 100 else chunk
                comparison += f"- {summary}\n"
            comparison += "\n"
        
        comparison += "I don't make judgments about which lab is 'best' as that depends on your specific needs. Each lab has different equipment and capabilities."
        
        return comparison
    
    return answer

def process_query(original_query, session_id=None, top_k=3):
    """Process a user query through the complete pipeline."""
    # Initialize or get conversation history for this session
    if session_id is not None:
        if session_id not in conversation_history:
            conversation_history[session_id] = []
        history = conversation_history[session_id]
    else:
        history = None
    
    # Special handling for very basic queries
    if original_query.lower() in ["hey", "hi", "hello"]:
        answer = "Hello! I'm a lab assistant. I can help you with questions about lab procedures, equipment, and facilities. What specific lab information are you looking for today?"
        
        # Update conversation history if session tracking is enabled
        if session_id is not None:
            conversation_history[session_id].append((original_query, answer))
        
        return answer
    
    # Special handling for lab listing queries
    if any(phrase in original_query.lower() for phrase in [
        "available labs", "which labs", "what labs", "list of labs", "labs available", "list labs"
    ]):
        # Get the labs list chunk
        labs_chunks = []
        for chunk, embedding, metadata in VECTOR_DB:
            if metadata.get('content_type') == 'labs_list':
                labs_chunks.append((chunk, 1.0, metadata))
        
        if labs_chunks:
            answer = generate_answer("What labs are available in the system?", labs_chunks)
            
            # Update conversation history
            if session_id is not None:
                conversation_history[session_id].append((original_query, answer))
            
            return answer
    
    # Handle follow-up responses that should be interpreted as asking about available labs
    if history and len(history) > 0:
        last_query, last_response = history[-1]
        
        if "I'm specialized in answering questions about labs" in last_response and any(phrase in original_query.lower() for phrase in [
            "that's exactly what i'm doing", 
            "thats exactly what im doing",
            "that is what i'm asking",
            "that is what i am asking",
            "i am",
            "i did"
        ]):
            # Get the labs list chunk
            labs_chunks = []
            for chunk, embedding, metadata in VECTOR_DB:
                if metadata.get('content_type') == 'labs_list':
                    labs_chunks.append((chunk, 1.0, metadata))
            
            if labs_chunks:
                answer = generate_answer("What labs are available in the system?", labs_chunks)
                
                # Update conversation history
                if session_id is not None:
                    conversation_history[session_id].append((original_query, answer))
                
                return answer
    
    # Step 1: Rewrite the query
    rewritten_query = rewrite_query(original_query, history)
    
    # Check if the rewritten query indicates a greeting or off-topic question
    if "greeting" in rewritten_query.lower():
        answer = "Hello! I'm a lab assistant. I can help you with questions about lab procedures, equipment, and facilities. What specific lab information are you looking for today?"
    elif "not a lab-related question" in rewritten_query.lower():
        answer = "I'm specialized in answering questions about labs. Could you ask me something related to lab procedures, equipment, or facilities?"
    else:
        # For questions about "which lab is good" or similar subjective queries
        is_lab_comparison = False
        if ("which" in original_query.lower() or "what" in original_query.lower()) and "lab" in original_query.lower() and any(word in original_query.lower() for word in ["good", "best", "better", "recommended"]):
            is_lab_comparison = True
            
        # Step 2: Retrieve relevant chunks - use higher threshold for comparisons
        threshold = 0.45 if is_lab_comparison else 0.5
        # Use higher top_k for comparisons to get more labs
        comparison_top_k = 8 if is_lab_comparison else top_k
        
        retrieved_chunks = retrieve(rewritten_query, comparison_top_k, threshold=threshold)
        
        if not retrieved_chunks:
            if is_lab_comparison:
                answer = "I don't have enough information to compare different labs. Please ask about specific lab features instead."
            else:
                answer = "I don't have specific information about that in my lab database. Could you try rephrasing your question or ask about a different lab topic?"
        else:
            # Step 3: Generate answer using rewritten query and retrieved chunks
            answer = generate_answer(rewritten_query, retrieved_chunks)
    
    # Update conversation history if session tracking is enabled
    if session_id is not None:
        conversation_history[session_id].append((original_query, answer))
        # Keep history manageable (last 5 exchanges)
        if len(conversation_history[session_id]) > 5:
            conversation_history[session_id] = conversation_history[session_id][-5:]
    
    return answer

# Initialize the database on startup
def initialize_database():
    logging.debug("Initializing database")
    read_files_in_directory(LABS_DIRECTORY)
    logging.debug(f'Loaded {len(dataset)} entries')
    
    # Add a special chunk for lab names list
    all_lab_names = sorted(set(lab_name for lab_name, _ in dataset))
    lab_list_chunk = "Available Labs Information:\n\n"
    lab_list_chunk += "The following labs are available in our system:\n"
    for lab_name in all_lab_names:
        lab_list_chunk += f"- {lab_name}\n"
    
    # Add this special chunk with metadata to mark it as a lab list
    add_chunk_to_database(lab_list_chunk, {'lab_name': 'System', 'content_type': 'labs_list'})
    logging.debug(f'Added special labs list chunk to the database')
    
    # Process each lab's content
    for lab_name, content in dataset:
        chunks = split_text_into_semantic_chunks(content)
        for chunk in chunks:
            add_chunk_to_database(chunk, {'lab_name': lab_name})
        logging.debug(f'Added chunks from {lab_name} to the database')
    
    logging.debug(f'Vector database contains {len(VECTOR_DB)} entries')

# Flask routes
@app.route('/generate', methods=['POST'])
def generate():
    data = request.json
    input_text = data.get('text')
    session_id = data.get('session_id')  # Optional session ID for conversation tracking
    
    if not input_text:
        return jsonify({'error': 'Text is required'}), 400

    try:
        response = process_query(input_text, session_id)
        return jsonify({'response': response})
    except Exception as e:
        app.logger.error(f"Failed to generate response: {e}")
        return jsonify({'error': 'Failed to generate response'}), 500

if __name__ == '__main__':
    # Initialize models first, then the database
    initialize_models()
    initialize_database()
    
    # Start the Flask server
    app.run(host='0.0.0.0', port=5000, debug=True)