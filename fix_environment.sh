#!/bin/bash

echo "Fixing environment for the AGLC RAG Chatbot..."

# Uninstall problematic packages
echo "Uninstalling potentially conflicting packages..."
pip3 uninstall -y transformers
pip3 uninstall -y torch
pip3 uninstall -y sentence-transformers
pip3 uninstall -y langchain-huggingface

# Install required dependencies
echo "Installing dependencies..."
pip3 install -r requirements.txt
pip3 install scikit-learn numpy

# Clean up any existing FAISS index
echo "Cleaning up existing FAISS index..."
rm -rf faiss_index

# Run the rebuild script to completely rebuild the index
echo "Rebuilding index from scratch..."
python3 rebuild_index.py

echo "Environment fixed! You can now run the application."
echo "1. The index has been rebuilt automatically"
echo "2. Start the server: python3 app.py" 