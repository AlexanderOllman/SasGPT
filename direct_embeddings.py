"""
Direct implementation of sentence-transformer embeddings to avoid PyTorch compatibility issues
"""

from typing import Any, Dict, List
import numpy as np
from langchain_core.embeddings import Embeddings
from sentence_transformers import SentenceTransformer

class DirectSentenceTransformerEmbeddings(Embeddings):
    """
    A simplified implementation of sentence-transformer embeddings
    that bypasses the langchain-huggingface integration to avoid
    PyTorch version compatibility issues.
    """
    
    def __init__(self, model_name: str = "all-minilm-l6-v2"):
        """Initialize with model_name."""
        try:
            self.model = SentenceTransformer(model_name)
            self.model_name = model_name
        except Exception as e:
            print(f"Error loading model: {e}")
            raise
    
    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        """Embed a list of documents using the sentence transformer model."""
        try:
            embeddings = self.model.encode(texts, convert_to_numpy=True)
            return embeddings.tolist()
        except Exception as e:
            print(f"Error embedding documents: {e}")
            raise
    
    def embed_query(self, text: str) -> List[float]:
        """Embed a query using the sentence transformer model."""
        try:
            embedding = self.model.encode(text, convert_to_numpy=True)
            return embedding.tolist()
        except Exception as e:
            print(f"Error embedding query: {e}")
            raise 