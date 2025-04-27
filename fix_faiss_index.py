"""
Script to fix the FAISS index by loading and resaving it with the new embeddings
"""

import os
import shutil
from simple_embeddings import SimpleTfidfEmbeddings
from langchain_community.vectorstores import FAISS
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

def fix_faiss_index():
    """Fix the FAISS index by recreating it if there are issues"""
    
    # Check if faiss_index directory exists
    if not os.path.exists('faiss_index'):
        logger.error("FAISS index directory doesn't exist. Please run initialize_db.py first.")
        return False
    
    try:
        # Try to load the index with dangerous deserialization allowed
        logger.info("Attempting to load FAISS index...")
        embeddings = SimpleTfidfEmbeddings(max_features=2000)
        vector_db = FAISS.load_local("faiss_index", embeddings, allow_dangerous_deserialization=True)
        
        # Backup the old index
        logger.info("Creating backup of old index...")
        if os.path.exists('faiss_index_backup'):
            shutil.rmtree('faiss_index_backup')
        shutil.copytree('faiss_index', 'faiss_index_backup')
        
        # Save the index properly
        logger.info("Saving FAISS index with new format...")
        vector_db.save_local("faiss_index")
        logger.info("FAISS index fixed successfully!")
        return True
    
    except Exception as e:
        logger.error(f"Error fixing FAISS index: {e}")
        logger.info("Please run initialize_db.py to recreate the index from scratch.")
        return False

if __name__ == "__main__":
    fix_faiss_index() 