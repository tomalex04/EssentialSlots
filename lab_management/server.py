from flask import Flask, request, jsonify
import json
import requests
import logging
from flask_cors import CORS

app = Flask(__name__)

OLLAMA_API_URL = "http://localhost:11434/api/generate"  # Correct Ollama API URL

logging.basicConfig(level=logging.DEBUG)

@app.route('/generate', methods=['POST'])
def generate():
    data = request.json
    input_text = data['text']
    app.logger.debug(f"Received text: {input_text}")
    
    try:
        with requests.post(OLLAMA_API_URL, json={'model': 'llama3.2:3b', 'prompt': input_text}, stream=True) as response:
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
