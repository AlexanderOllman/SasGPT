# AGLC RAG Chatbot

A lightweight chatbot for answering questions about the Australian Guide to Legal Citation (AGLC) using Retrieval-Augmented Generation (RAG) with a FAISS vector database.

## Features

- Answers questions about AGLC with specific citations
- Uses a FAISS vector database for efficient semantic search
- Provides page number references and direct links to the PDF
- Supports two embedding types for comparison:
  - TF-IDF embeddings (lightweight, no PyTorch dependencies)
  - OpenAI embeddings (more semantic understanding)
- Mobile-friendly interface
- Easy to deploy

## Setup

### Prerequisites

- Python 3.8 or higher
- An OpenAI API key (for the language model and OpenAI embeddings)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
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

1. Initialize the TF-IDF vector database (default):
   ```bash
   python initialize_db.py
   ```

2. (Optional) Initialize the OpenAI embeddings vector database for comparison:
   ```bash
   python initialize_openai_db.py
   ```

Both databases will be created from the `AGLC4.pdf` file (make sure this file is in the project root).

## Running the Application

1. Start the server:
   ```bash
   python app.py
   ```

2. Access the chatbot at: http://localhost:8005

## Using the Chatbot

1. Type your question about AGLC in the input field
2. The chatbot will provide an answer with citations linked to specific pages in the PDF
3. Toggle between TF-IDF and OpenAI embeddings using the switch in the header
4. Click on a citation link to see more context from that part of the document

## Comparing Embedding Types

You can compare results from both embedding types directly in the chatbot interface by toggling between them. Alternatively, you can use the comparison script:

```bash
python compare_embeddings.py "your search query"
```

This will show results from both embedding models side by side and provide metrics on how similar they are.

## Files Overview

- `app.py`: FastAPI application that serves the chatbot
- `initialize_db.py`: Script to initialize the TF-IDF vector database
- `initialize_openai_db.py`: Script to initialize the OpenAI embeddings vector database
- `simple_embeddings.py`: Custom TF-IDF embeddings implementation
- `compare_embeddings.py`: Script to compare results from both embedding types
- `static/`: Directory containing frontend files (HTML, CSS, JavaScript)

## Troubleshooting

If you encounter issues, see the `TROUBLESHOOTING.md` file for common problems and solutions.

## License

[MIT License](LICENSE) # SasGPT
