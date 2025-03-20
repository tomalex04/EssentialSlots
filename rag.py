import os
import re
import ollama
import chromadb
import logging
from chromadb.config import Settings
from chromadb.utils import embedding_functions
from flask import Flask, request, jsonify
from flask_cors import CORS

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logging.getLogger('watchdog').setLevel(logging.WARNING)  # Adjust logging level for watchdog

# Initialize ChromaDB client with the new configuration
chroma_client = chromadb.Client(Settings(persist_directory="./chroma_db"))

# Load the dataset
dataset = []
LABS_DIRECTORY = '/home/tom/Desktop/lab_files/'  # Update this to the path of your labs directory

def read_files_in_directory(directory):
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
                    logging.debug(f"Content of {file_path}: {content[:1000]}")  # Log the first 1000 characters of the content
                    if content.strip():  # Check if content is not empty
                        lab_name = os.path.basename(root)
                        dataset.append((lab_name, content))
                        logging.debug(f"Added file content from {file_path} to dataset")
                    else:
                        logging.debug(f"File {file_path} is empty")
            except Exception as e:
                logging.error(f"Failed to read file {file_path}: {e}")

read_files_in_directory(LABS_DIRECTORY)
logging.debug(f'Loaded {len(dataset)} entries')

# Implement the retrieval system
EMBEDDING_MODEL = 'hf.co/CompendiumLabs/bge-base-en-v1.5-gguf'
LANGUAGE_MODEL = 'hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF'

# Each element in the VECTOR_DB will be a tuple (chunk, embedding, metadata)
VECTOR_DB = []

def add_chunk_to_database(chunk, metadata):
    embedding = ollama.embed(model=EMBEDDING_MODEL, input=chunk)['embeddings'][0]
    VECTOR_DB.append((chunk, embedding, metadata))

def split_text_into_chunks(text, chunk_size=100):
    sentences = re.split(r'(?<=[.!?]) +', text)
    chunks = []
    current_chunk = []
    current_length = 0
    for sentence in sentences:
        sentence_length = len(sentence.split())
        if current_length + sentence_length > chunk_size:
            chunks.append(' '.join(current_chunk))
            current_chunk = []
            current_length = 0
        current_chunk.append(sentence)
        current_length += sentence_length
    if current_chunk:
        chunks.append(' '.join(current_chunk))
    return chunks

for lab_name, content in dataset:
    chunks = split_text_into_chunks(content)
    for chunk in chunks:
        add_chunk_to_database(chunk, {'lab_name': lab_name})
    logging.debug(f'Added chunks from {lab_name} to the database')

# Print the contents of VECTOR_DB to verify that it has been populated correctly
logging.debug(f'Vector database contains {len(VECTOR_DB)} entries')
for chunk, embedding, metadata in VECTOR_DB:
    logging.debug(f'Chunk: {chunk}, Metadata: {metadata}')

def cosine_similarity(a, b):
    dot_product = sum([x * y for x, y in zip(a, b)])
    norm_a = sum([x ** 2 for x in a]) ** 0.5
    norm_b = sum([x ** 2 for x in b]) ** 0.5
    return dot_product / (norm_a * norm_b)

def retrieve(query, top_n=3):
    query_embedding = ollama.embed(model=EMBEDDING_MODEL, input=query)['embeddings'][0]
    similarities = []
    for chunk, embedding, metadata in VECTOR_DB:
        similarity = cosine_similarity(query_embedding, embedding)
        similarities.append((chunk, similarity, metadata))
    similarities.sort(key=lambda x: x[1], reverse=True)
    logging.debug(f"Retrieved top {top_n} chunks for query")
    for chunk, similarity, metadata in similarities[:top_n]:
        logging.debug(f"Chunk: {chunk}, Similarity: {similarity}, Metadata: {metadata}")
    return similarities[:top_n]

@app.route('/generate', methods=['POST'])
def generate():
    data = request.json
    input_text = data.get('text')
    if not input_text:
        return jsonify({'error': 'Text is required'}), 400

    try:
        retrieved_knowledge = retrieve(input_text)

        if not retrieved_knowledge:
            return jsonify({'response': 'No relevant information found for the specified query.'})

        logging.debug(f"Retrieved knowledge: {retrieved_knowledge}")

        instruction_prompt = f'''You are a helpful chatbot.
        Use only the following pieces of context to answer the question. Don't make up any new information:
        {'\n'.join([f' - {chunk} [Lab: {metadata["lab_name"]}]' for chunk, similarity, metadata in retrieved_knowledge])}
        '''

        stream = ollama.chat(
            model=LANGUAGE_MODEL,
            messages=[
                {'role': 'system', 'content': instruction_prompt},
                {'role': 'user', 'content': input_text},
            ],
            stream=True,
        )

        full_response = ''.join([chunk['message']['content'] for chunk in stream])

        return jsonify({'response': full_response})

    except Exception as e:
        app.logger.error(f"Failed to generate response: {e}")
        return jsonify({'error': 'Failed to generate response'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
