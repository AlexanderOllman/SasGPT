# AGLC RAG Chatbot

A lightweight chatbot for answering questions about the Australian Guide to Legal Citation (AGLC) using Retrieval-Augmented Generation (RAG) with a FAISS vector database and OpenAI embeddings.

## Features

- Answers questions about AGLC with specific citations
- Uses a FAISS vector database powered by OpenAI embeddings for efficient semantic search
- Provides page number references and direct links to the PDF
- Mobile-friendly interface
- Easy to deploy

## Setup

### Prerequisites

- Python 3.8 or higher
- An OpenAI API key

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\\Scripts\\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create a `.env` file in the project root and add your OpenAI API key:
   ```
   OPENAI_API_KEY=your_api_key_here
   ```

### Setting Up the Vector Database

1. Initialize the OpenAI embeddings vector database:
   ```bash
   python initialize_openai_db.py
   ```

The database will be created from the `AGLC4.pdf` file (make sure this file is in the project root).

## Running the Application

1. Start the server using Uvicorn:
   ```bash
   uvicorn app:app --reload --port 8005
   ```
   *(Note: The original README suggested `python app.py`, but `uvicorn` is standard for FastAPI)*

2. Access the chatbot at: http://localhost:8005

## Using the Chatbot

1. Type your question about AGLC in the input field
2. The chatbot will provide an answer using OpenAI embeddings and the LLM.
3. Citations linked to specific pages in the PDF will be displayed.
4. Click on a citation link to see more context from that part of the document.

## Files Overview

- `app.py`: FastAPI application that serves the chatbot
- `initialize_openai_db.py`: Script to initialize the OpenAI embeddings vector database
- `static/`: Directory containing frontend files (HTML, CSS, JavaScript)
- `AGLC4.pdf`: The source document for the knowledge base
- `requirements.txt`: Python dependencies
- `.env`: Environment variables (contains OpenAI API Key)
- `README.md`: This file
- `TROUBLESHOOTING.md`: Common issues and solutions

## Troubleshooting

If you encounter issues, see the `TROUBLESHOOTING.md` file for common problems and solutions.

## License

[MIT License](LICENSE) # SasGPT
