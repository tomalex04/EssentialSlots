from flask import Flask, request, jsonify
import json
import requests
import logging
import os
import re
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)

OLLAMA_API_URL = "http://localhost:11434/api/generate"  # Correct Ollama API URL
DATABASE_CONFIG = {
    'user': 'root',
    'password': 'phpmyadmin',
    'host': 'localhost',
    'database': 'lab_management'
}

logging.basicConfig(level=logging.DEBUG)

def get_lab_info():
    conn = mysql.connector.connect(**DATABASE_CONFIG)
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT name, folder_path FROM labs")
    labs = cursor.fetchall()
    cursor.close()
    conn.close()
    return {lab['name']: lab['folder_path'] for lab in labs}

def retrieve_document_text(folder_path):
    if folder_path is None:
        return None
    files = os.listdir(folder_path)
    if files:
        file_path = os.path.join(folder_path, files[0])
        with open(file_path, 'r') as file:
            return file.read()
    return None

@app.route('/generate', methods=['POST'])
def generate():
    data = request.json
    input_text = data.get('text')
    if not input_text:
        return jsonify({'error': 'Text is required'}), 400

    app.logger.debug(f"Received text: {input_text}")

    try:
        labs_info = get_lab_info()
        app.logger.debug(f"Labs info: {labs_info}")

        # Find all lab names in the input text
        lab_names = [name for name in labs_info.keys() if re.search(r'\b' + re.escape(name) + r'\b', input_text, re.IGNORECASE)]

        # If no lab names are found, use all labs
        if not lab_names:
            lab_names = list(labs_info.keys())

        combined_document_content = ""
        for lab_name in lab_names:
            folder_path = labs_info[lab_name]
            if folder_path is None:
                app.logger.debug(f"Folder path not found for the specified lab: {lab_name}")
                continue

            app.logger.debug(f"Lab name: {lab_name}, Folder path: {folder_path}")

            # Retrieve the document content
            document_content = retrieve_document_text(folder_path)
            if document_content is None:
                app.logger.debug(f"Document not found for the specified lab: {lab_name}")
                continue

            app.logger.debug(f"Retrieved document content for {lab_name}: {document_content}")

            # Add markers to indicate the end of each lab's information
            combined_document_content += f"Information about {lab_name}:\n{document_content}\n\n######End of information about {lab_name}.\n\n"

        if not combined_document_content:
            return jsonify({'error': 'No document content found for the specified labs'}), 404

        # Combine the document content with the input text
        combined_prompt = input_text + "\n\n###\n\n" + combined_document_content
        app.logger.debug(f"Combined prompt: {combined_prompt}")

        # Send the combined prompt to the language model
        with requests.post(OLLAMA_API_URL, json={'model': 'llama3.2:1b', 'prompt': combined_prompt}, stream=True) as response:
            response.raise_for_status()
            full_response = ""

            for line in response.iter_lines():
                if line:
                    try:
                        chunk = line.decode('utf-8')  # Decode JSON line
                        json_chunk = json.loads(chunk)  # Parse JSON
                        full_response += json_chunk.get("response", "")  # Append response text
                    except json.JSONDecodeError as e:
                        app.logger.error(f"JSON decoding error: {e}")

            return jsonify({'response': full_response})

    except requests.exceptions.RequestException as e:
        app.logger.error(f"Request to Ollama failed: {e}")
        return jsonify({'error': 'Failed to get response from Ollama'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
