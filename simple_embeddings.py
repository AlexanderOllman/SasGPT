"""
Ultra-simple text embeddings implementation to avoid PyTorch and transformers dependencies
"""

import numpy as np
from typing import List
from langchain_core.embeddings import Embeddings
from sklearn.feature_extraction.text import TfidfVectorizer
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleTfidfEmbeddings(Embeddings):
    """
    A basic TF-IDF based embeddings implementation that doesn't rely on 
    transformers or PyTorch, making it much more compatible.
    
    This is less sophisticated than sentence-transformers but will work
    for basic RAG needs without any dependency issues.
    """
    
    def __init__(self, max_features=384):  # Set to 384 to match minilm-l6-v2 dimension
        """Initialize the TF-IDF vectorizer."""
        self.max_features = max_features
        self.vectorizer = TfidfVectorizer(
            max_features=max_features,
            stop_words='english',
            analyzer='word',
            ngram_range=(1, 2)
        )
        self.fitted = False
        self.documents = []  # store documents for fitting later
        logger.info(f"Initialized TF-IDF embeddings with dimension {max_features}")
        
    def fit_if_needed(self, texts):
        """Fit the vectorizer if not already fitted."""
        if not self.fitted:
            # Store these documents for later
            self.documents.extend(texts)
            # Fit the vectorizer
            logger.info(f"Fitting TF-IDF vectorizer on {len(self.documents)} documents...")
            self.vectorizer.fit(self.documents)
            self.fitted = True
            logger.info("TF-IDF vectorizer fitted successfully")
            
    def pad_vector(self, vector, target_dim=None):
        """Pad or truncate vector to target dimensions."""
        if target_dim is None:
            target_dim = self.max_features
            
        current_dim = len(vector)
        
        if current_dim == target_dim:
            return vector
        elif current_dim > target_dim:
            # Truncate if too long
            return vector[:target_dim]
        else:
            # Pad with zeros if too short
            return vector + [0.0] * (target_dim - current_dim)
        
    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        """Embed a list of documents using TF-IDF."""
        try:
            # Make sure the vectorizer is fitted
            self.fit_if_needed(texts)
            
            # Transform texts to vectors
            sparse_vectors = self.vectorizer.transform(texts)
            
            # Convert to dense vectors and ensure consistent dimensions
            dense_vectors = sparse_vectors.toarray().tolist()
            
            # Make sure all vectors have the right dimensions
            return [self.pad_vector(vector) for vector in dense_vectors]
            
        except Exception as e:
            logger.error(f"Error embedding documents: {e}")
            raise
    
    def embed_query(self, text: str) -> List[float]:
        """Embed a query using TF-IDF."""
        try:
            # Ensure the vectorizer has been fitted with at least one document
            if not self.fitted:
                self.fit_if_needed([text])
                
            # Transform text to vector
            sparse_vector = self.vectorizer.transform([text])
            
            # Convert to dense vector and ensure consistent dimensions
            dense_vector = sparse_vector.toarray()[0].tolist()
            
            # Make sure vector has the right dimensions
            return self.pad_vector(dense_vector)
            
        except Exception as e:
            logger.error(f"Error embedding query: {e}")
            raise 