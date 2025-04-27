import os
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from dotenv import load_dotenv

# Import our simple TF-IDF implementation
from simple_embeddings import SimpleTfidfEmbeddings

# Load environment variables
load_dotenv()

# Function to initialize the vector database
def initialize_vector_db(pdf_path="AGLC4.pdf", chunk_size=1000, chunk_overlap=200):
    """
    Initialize a FAISS vector database from a PDF file
    
    Args:
        pdf_path: Path to the PDF file
        chunk_size: Size of each chunk
        chunk_overlap: Overlap between chunks
    
    Returns:
        FAISS vector database
    """
    print(f"Loading PDF from {pdf_path}...")
    loader = PyPDFLoader(pdf_path)
    documents = loader.load()
    
    # Add metadata for page number to each document
    for doc in documents:
        # Page numbers in PyPDFLoader are 0-indexed, but we want 1-indexed for citations
        doc.metadata["page"] = doc.metadata.get("page", 0) + 1
    
    print(f"Loaded {len(documents)} pages from PDF")
    
    # Split documents into chunks
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        separators=["\n\n", "\n", " ", ""]
    )
    chunks = text_splitter.split_documents(documents)
    print(f"Split into {len(chunks)} chunks")
    
    # Create embeddings using our simple TF-IDF implementation
    print("Initializing embeddings model...")
    embeddings = SimpleTfidfEmbeddings(max_features=2000)
    
    # Create and save FAISS vector database
    print("Creating vector database...")
    vector_db = FAISS.from_documents(chunks, embeddings)
    
    # Save the vector database locally with serialization config
    print("Saving vector database...")
    vector_db.save_local("faiss_index")
    print("Vector database initialized and saved to faiss_index/")
    
    return vector_db

if __name__ == "__main__":
    # No longer need OpenAI API key since we're using a local model
    initialize_vector_db() 