"""
Script to compare results from TF-IDF and OpenAI embeddings for a given query
"""

import os
import sys
import logging
from langchain_community.vectorstores import FAISS
from langchain_openai import OpenAIEmbeddings
from dotenv import load_dotenv
from simple_embeddings import SimpleTfidfEmbeddings

# Set up logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

def get_embeddings(embedding_type):
    """Get embeddings model based on type"""
    if embedding_type == "openai":
        return OpenAIEmbeddings()
    else:
        return SimpleTfidfEmbeddings(max_features=384)

def get_vector_db(embedding_type):
    """Get vector database based on embedding type"""
    embeddings = get_embeddings(embedding_type)
    
    # Choose the appropriate index path
    index_path = "faiss_openai_index" if embedding_type == "openai" else "faiss_index"
    
    try:
        logger.info(f"Loading {embedding_type} FAISS index from {index_path}...")
        vector_db = FAISS.load_local(index_path, embeddings, allow_dangerous_deserialization=True)
        logger.info(f"Loaded {embedding_type} FAISS index successfully")
        return vector_db
    except Exception as e:
        logger.error(f"Failed to load {embedding_type} FAISS index: {e}")
        logger.info(f"Make sure to initialize the {embedding_type} index first")
        return None

def compare_results(query, k=5):
    """Compare results from TF-IDF and OpenAI embeddings for a query"""
    # Check if OpenAI API key is set
    if not os.getenv("OPENAI_API_KEY"):
        logger.error("OPENAI_API_KEY environment variable not set")
        return
    
    # Get vector databases
    tfidf_db = get_vector_db("tfidf")
    openai_db = get_vector_db("openai")
    
    if not tfidf_db or not openai_db:
        return
    
    # Search for relevant chunks
    logger.info(f"Searching for: '{query}'")
    
    # TF-IDF results
    logger.info("TF-IDF results:")
    tfidf_chunks = tfidf_db.similarity_search(query, k=k)
    print("\n--- TF-IDF Top Results ---")
    for i, chunk in enumerate(tfidf_chunks):
        print(f"\n[{i+1}] Page {chunk.metadata.get('page', 'unknown')}:")
        print(f"{chunk.page_content[:200]}...")
    
    # OpenAI results
    logger.info("OpenAI results:")
    openai_chunks = openai_db.similarity_search(query, k=k)
    print("\n--- OpenAI Top Results ---")
    for i, chunk in enumerate(openai_chunks):
        print(f"\n[{i+1}] Page {chunk.metadata.get('page', 'unknown')}:")
        print(f"{chunk.page_content[:200]}...")
    
    # Compare overlap
    tfidf_pages = {chunk.metadata.get('page') for chunk in tfidf_chunks}
    openai_pages = {chunk.metadata.get('page') for chunk in openai_chunks}
    overlap = tfidf_pages.intersection(openai_pages)
    
    print(f"\n--- Comparison ---")
    print(f"TF-IDF pages: {sorted(list(tfidf_pages))}")
    print(f"OpenAI pages: {sorted(list(openai_pages))}")
    print(f"Overlap: {len(overlap)} pages ({sorted(list(overlap))})")
    print(f"Similarity: {len(overlap) / k * 100:.1f}% of results are the same")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python compare_embeddings.py 'your search query'")
        sys.exit(1)
    
    query = sys.argv[1]
    compare_results(query) 