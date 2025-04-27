import os
from langchain_community.document_loaders import PyPDFLoader
from langchain_textsplitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_openai import OpenAIEmbeddings
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Check for OpenAI API key
if not os.getenv("OPENAI_API_KEY"):
    raise ValueError("OPENAI_API_KEY environment variable not set")

# Function to initialize the vector database with OpenAI embeddings
def initialize_openai_vector_db(pdf_path="AGLC4.pdf", chunk_size=1000, chunk_overlap=200):
    """
    Initialize a FAISS vector database from a PDF file using OpenAI embeddings
    
    Args:
        pdf_path: Path to the PDF file
        chunk_size: Size of each chunk
        chunk_overlap: Overlap between chunks
    
    Returns:
        FAISS vector database
    """
    logger.info(f"Loading PDF from {pdf_path}...")
    loader = PyPDFLoader(pdf_path)
    documents = loader.load()
    
    # Add metadata for page number to each document
    for doc in documents:
        # Page numbers in PyPDFLoader are 0-indexed, but we want 1-indexed for citations
        doc.metadata["page"] = doc.metadata.get("page", 0) + 1
    
    logger.info(f"Loaded {len(documents)} pages from PDF")
    
    # Split documents into chunks
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        separators=["\n\n", "\n", " ", ""]
    )
    chunks = text_splitter.split_documents(documents)
    logger.info(f"Split into {len(chunks)} chunks")
    
    # Create embeddings using OpenAI embeddings
    logger.info("Initializing OpenAI embeddings model...")
    embeddings = OpenAIEmbeddings()
    
    # Create and save FAISS vector database
    logger.info("Creating vector database with OpenAI embeddings...")
    vector_db = FAISS.from_documents(chunks, embeddings)
    
    # Save the vector database locally
    logger.info("Saving vector database...")
    vector_db.save_local("faiss_openai_index")
    logger.info("OpenAI-based vector database initialized and saved to faiss_openai_index/")
    
    return vector_db

if __name__ == "__main__":
    initialize_openai_vector_db() 