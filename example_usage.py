"""
Example of using all-MiniLM-L6-v2 embeddings directly
"""

from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

def main():
    print("Loading all-MiniLM-L6-v2 model...")
    # Load the model
    model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
    
    # Example legal sentences
    sentences = [
        "The case was dismissed due to lack of evidence.",
        "The judge ruled in favor of the plaintiff.",
        "The defendant was found guilty by the jury.",
        "I need to cite a journal article in my legal brief.",
        "What's the correct citation format for Australian case law?",
        "How do I cite legislation in AGLC format?",
        "I'm writing a paper about contract law"
    ]
    
    # Encode sentences to get embeddings
    print("Generating embeddings...")
    embeddings = model.encode(sentences)
    
    # Show dimensions of the embeddings
    print(f"Each embedding has {embeddings.shape[1]} dimensions")
    
    # Find similar sentences using cosine similarity
    print("\nComparing sentence similarities:")
    for i, sentence1 in enumerate(sentences):
        print(f"\nSimilarities to: '{sentence1}'")
        
        # Calculate similarities with all other sentences
        similarities = cosine_similarity([embeddings[i]], embeddings)[0]
        
        # Sort by similarity (excluding the sentence itself)
        most_similar = sorted(
            [(j, sim) for j, sim in enumerate(similarities) if j != i],
            key=lambda x: x[1],
            reverse=True
        )
        
        # Print the top 2 most similar sentences
        for j, sim in most_similar[:2]:
            print(f"- '{sentences[j]}' (Similarity: {sim:.4f})")

if __name__ == "__main__":
    main() 