"""
Script to completely rebuild the FAISS index from scratch
"""

import os
import shutil
import logging
from initialize_db import initialize_vector_db

# Set up logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def rebuild_faiss_index():
    """
    Completely rebuilds the FAISS index from scratch,
    solving any dimension mismatch issues.
    """
    # Remove existing index if it exists
    if os.path.exists('faiss_index'):
        logger.info("Removing existing FAISS index...")
        
        # Create a backup first
        if not os.path.exists('faiss_index_backup'):
            logger.info("Creating backup of existing index...")
            shutil.copytree('faiss_index', 'faiss_index_backup')
            logger.info("Backup created at faiss_index_backup/")
        
        # Remove the index
        shutil.rmtree('faiss_index')
        logger.info("Existing index removed")
    
    # Rebuild the index
    logger.info("Building new FAISS index from scratch...")
    vector_db = initialize_vector_db(pdf_path="AGLC4.pdf")
    logger.info("FAISS index rebuilt successfully!")
    
    return True

if __name__ == "__main__":
    rebuild_faiss_index() 