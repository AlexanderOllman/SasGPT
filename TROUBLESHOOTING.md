# Troubleshooting Guide

## PyTorch Compatibility Issues

If you're seeing the error `module 'torch' has no attribute 'compiler'`, we've implemented an alternative solution that completely eliminates the dependency on PyTorch and transformer libraries.

### Solution: Use TF-IDF Embeddings

We've created a custom TF-IDF based embeddings implementation that avoids the dependency issues completely:

1. Make sure all files are updated to the latest versions:
   - `simple_embeddings.py` (new file with TF-IDF implementation)
   - `initialize_db.py` (updated to use TF-IDF)
   - `app.py` (updated to use TF-IDF)
   - `fix_faiss_index.py` (updated to use TF-IDF)
   - `rebuild_index.py` (new file to rebuild the index from scratch)

2. Run the fix_environment script:
   ```bash
   # Make the script executable
   chmod +x fix_environment.sh
   
   # Run the script
   ./fix_environment.sh
   ```

3. The script will automatically rebuild your index, but if you need to manually rebuild:
   ```bash
   python3 rebuild_index.py
   ```

4. Start the server:
   ```bash
   python3 app.py
   ```

This solution uses scikit-learn's TF-IDF vectorizer instead of neural embeddings, which is simpler but still effective for many RAG applications.

### About TF-IDF vs Neural Embeddings

TF-IDF (Term Frequency-Inverse Document Frequency) is a simpler approach than neural embeddings:

- **Pros**: No deep learning dependencies, faster, no GPU needed, reliable
- **Cons**: Less semantic understanding, might not capture nuanced meaning as well

For most legal document RAG applications, TF-IDF still performs well especially when search terms closely match document content.

## FAISS Index Loading Issues

### Dimension Mismatch Error

If you see an `AssertionError: assert d == self.d` error when trying to search, this means there's a dimension mismatch between your current embeddings and the stored vectors in the FAISS index. This happens when:

1. You've changed embedding methods (e.g., from neural embeddings to TF-IDF)
2. You've changed embedding dimensions (e.g., different max_features settings)

The solution is to completely rebuild the index:

```bash
python3 rebuild_index.py
```

This script will:
1. Back up your existing index
2. Remove the old index
3. Create a new index from scratch with consistent dimensions

### Other FAISS Issues

If you encounter other errors with FAISS index loading:

1. Try to fix the index:
   ```bash
   python3 fix_faiss_index.py
   ```

2. If that doesn't work, delete the faiss_index directory and reinitialize:
   ```bash
   rm -rf faiss_index
   python3 initialize_db.py
   ```

## Template Errors

If you see errors like `KeyError: "Input to PromptTemplate is missing variables {'xxx'}"`, this means there's an issue with the variables in your prompt template:

1. The most common cause is using curly braces `{variable}` in your template text that should be literal text, not variables.

2. To fix this, escape the curly braces by doubling them:
   ```
   # Instead of:
   "Include a citation in your answer with this format: [citation{number}]"
   
   # Use:
   "Include a citation in your answer with this format: [citation{{number}}]"
   ```

3. After fixing the template, restart your application.

## Other Common Issues

### Missing Dependencies

If you encounter errors related to missing dependencies:

```bash
pip3 install -r requirements.txt
```

### OpenAI API Key Issues

If you encounter errors related to the OpenAI API:

1. Make sure you have a valid OpenAI API key in your `.env` file:
   ```
   OPENAI_API_KEY=your_key_here
   ```

2. Try testing your API key with a simple script:
   ```python
   import os
   from openai import OpenAI
   from dotenv import load_dotenv

   load_dotenv()
   client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
   completion = client.chat.completions.create(
     model="gpt-3.5-turbo",
     messages=[{"role": "user", "content": "Hello!"}]
   )
   print(completion.choices[0].message.content)
   ``` 