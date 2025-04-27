import os
import re
import tiktoken
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv
from langchain_community.vectorstores import FAISS
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
import logging

# Import our simple TF-IDF implementation
from simple_embeddings import SimpleTfidfEmbeddings

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Check for OpenAI API key (still needed for the LLM)
if not os.getenv("OPENAI_API_KEY"):
    raise ValueError("OPENAI_API_KEY environment variable not set")

# Initialize FastAPI app
app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models for request and response
class ChatRequest(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = []
    embedding_type: Optional[str] = "openai"  # Default to OpenAI

class ChatResponse(BaseModel):
    answer: str
    citations: List[Dict[str, Any]]
    embedding_type: str
    cost: Dict[str, Any]

class EmbeddingToggleRequest(BaseModel):
    embedding_type: str  # "tfidf" or "openai"

class EmbeddingToggleResponse(BaseModel):
    success: bool
    embedding_type: str
    message: str

# PDF URL for citations
PDF_URL = "https://law.unimelb.edu.au/__data/assets/pdf_file/0005/3181325/AGLC4-with-Bookmarks-1.pdf"

# Initialize vector database and LLM
tfidf_embeddings = None
openai_embeddings = None
tfidf_vector_db = None
openai_vector_db = None
llm = None
current_embedding_type = "openai"  # Default to OpenAI
encoding = tiktoken.get_encoding("cl100k_base")  # For gpt-4 token counting

def count_tokens(text):
    """Count the number of tokens in a text string"""
    return len(encoding.encode(text))

def calculate_cost(token_count, model="gpt-4o-mini", is_input=True):
    """Calculate the cost in USD based on token count and model"""
    cost_rates = {
        "gpt-4o-mini": {"input": 0.00015, "output": 0.00060},  # per 1K tokens
        "text-embedding-ada-002": {"input": 0.00010, "output": 0.00010}
    }
    
    rate_key = "input" if is_input else "output"
    rate = cost_rates.get(model, {}).get(rate_key, 0)
    
    return (token_count / 1000) * rate

def get_tfidf_embeddings():
    global tfidf_embeddings
    if tfidf_embeddings is None:
        try:
            logger.info("Initializing SimpleTfidfEmbeddings...")
            tfidf_embeddings = SimpleTfidfEmbeddings(max_features=384)  # Match dimensions with OpenAI
            logger.info("TF-IDF Embeddings initialized successfully")
        except Exception as e:
            logger.error(f"Error initializing TF-IDF embeddings: {e}")
            raise
    return tfidf_embeddings

def get_openai_embeddings():
    global openai_embeddings
    if openai_embeddings is None:
        try:
            logger.info("Initializing OpenAIEmbeddings...")
            openai_embeddings = OpenAIEmbeddings()
            logger.info("OpenAI Embeddings initialized successfully")
        except Exception as e:
            logger.error(f"Error initializing OpenAI embeddings: {e}")
            raise
    return openai_embeddings

def get_tfidf_vector_db():
    global tfidf_vector_db
    if tfidf_vector_db is None:
        try:
            # Load from local storage with allow_dangerous_deserialization=True for backward compatibility
            logger.info("Attempting to load TF-IDF FAISS index...")
            tfidf_vector_db = FAISS.load_local("faiss_index", get_tfidf_embeddings(), allow_dangerous_deserialization=True)
            logger.info("Loaded TF-IDF FAISS index from local storage")
        except Exception as e:
            logger.error(f"Error loading TF-IDF FAISS index: {e}")
            logger.info("TF-IDF index not found. Please run initialize_db.py first.")
            # Option to return None or raise an error
            return None
    return tfidf_vector_db

def get_openai_vector_db():
    global openai_vector_db
    if openai_vector_db is None:
        try:
            # Load from local storage
            logger.info("Attempting to load OpenAI FAISS index...")
            openai_vector_db = FAISS.load_local("faiss_openai_index", get_openai_embeddings(), allow_dangerous_deserialization=True)
            logger.info("Loaded OpenAI FAISS index from local storage")
        except Exception as e:
            logger.error(f"Error loading OpenAI FAISS index: {e}")
            logger.info("OpenAI index not found. Please run initialize_openai_db.py first.")
            # Option to return None or raise an error
            return None
    return openai_vector_db

def get_vector_db(embedding_type="openai"):
    """Get the appropriate vector database based on embedding type"""
    if embedding_type == "openai":
        db = get_openai_vector_db()
        if db is None:
            logger.warning("OpenAI DB not available, falling back to TF-IDF")
            return get_tfidf_vector_db()
        return db
    else:
        db = get_tfidf_vector_db()
        if db is None:
            logger.warning("TF-IDF DB not available, falling back to OpenAI")
            return get_openai_vector_db()
        return db

def get_llm():
    global llm
    if llm is None:
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.2)  # Using gpt-4.1-nano equivalent
    return llm

# Function to create citation links from retrieved chunks
def process_citations(context_chunks):
    citations = []
    for i, chunk in enumerate(context_chunks):
        page_num = chunk.metadata.get("page", 1)
        citation_url = f"{PDF_URL}#page={page_num}"
        # Create a unique identifier for this citation
        citation_id = f"citation-{i+1}"
        citations.append({
            "id": citation_id,
            "text": chunk.page_content,
            "url": citation_url,
            "page": page_num
        })
    return citations

# Create prompt template for RAG
RAG_PROMPT_TEMPLATE = """
You are an assistant that provides information based on the AGLC (Australian Guide to Legal Citation).
You are given a question and relevant context from the guide.
Answer the question based only on the provided context, without making up information.

When information comes from the context, include a citation in your answer with this format: [citation{{number}}].
The number should correspond to the citation number in the citations list.

Format your response using Markdown for better readability. Use:
- Bullet points for lists
- Numbered lists where appropriate
- Bold for emphasis
- Headings for sections
- Code blocks for examples or formatting demonstrations

Question: {question}

Context:
{context}

Answer the question based on the context provided. Include citations [citation{{number}}] where appropriate. 
Be concise and precise. If the context doesn't contain the answer, say so.
Your style of answer should be one of an obnoxious and sarcastic know-it-all, who doesn't like to think they're smarter than everyone else, but they are. 
"""

# API endpoint to toggle embedding type
@app.post("/api/toggle_embeddings", response_model=EmbeddingToggleResponse)
async def toggle_embeddings(request: EmbeddingToggleRequest):
    global current_embedding_type
    
    if request.embedding_type not in ["tfidf", "openai"]:
        raise HTTPException(status_code=400, detail="Invalid embedding type. Must be 'tfidf' or 'openai'")
    
    previous_type = current_embedding_type
    current_embedding_type = request.embedding_type
    
    # Ensure the vector database is loaded
    db_to_check = get_tfidf_vector_db() if current_embedding_type == "tfidf" else get_openai_vector_db()
    if db_to_check is None:
        message = f"Switched to {current_embedding_type} but index is not available. Please initialize it."
        logger.warning(f"Cannot switch to {current_embedding_type}: index not found.")
    else:
        message = f"Switched to {current_embedding_type} embeddings"
        logger.info(f"Embedding type changed from {previous_type} to {current_embedding_type}")
    
    return {
        "success": db_to_check is not None,
        "embedding_type": current_embedding_type,
        "message": message
    }

# Create endpoint for chat
@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    user_message = request.message
    embedding_type = request.embedding_type or current_embedding_type
    
    # Track token usage and costs
    cost_tracking = {
        "embedding": {
            "tokens": 0,
            "cost": 0.0
        },
        "chat": {
            "input_tokens": 0,
            "output_tokens": 0,
            "input_cost": 0.0,
            "output_cost": 0.0
        },
        "total_cost": 0.0
    }
    
    # Get vector database based on requested embedding type
    vector_db = get_vector_db(embedding_type)
    if vector_db is None:
        logger.error(f"Vector database for {embedding_type} is not available.")
        raise HTTPException(status_code=500, detail=f"Vector database for {embedding_type} is not initialized.")
    
    # Count tokens for embedding (only if using OpenAI)
    if embedding_type == "openai":
        embedding_tokens = count_tokens(user_message)
        cost_tracking["embedding"]["tokens"] = embedding_tokens
        embedding_cost = calculate_cost(embedding_tokens, model="text-embedding-ada-002")
        cost_tracking["embedding"]["cost"] = embedding_cost
    else:
        cost_tracking["embedding"]["cost"] = 0.0
    
    # Search for relevant documents
    context_chunks = vector_db.similarity_search(user_message, k=5)
    
    # Process citations
    citations = process_citations(context_chunks)
    
    # Create context from retrieved chunks
    context_text = ""
    for i, chunk in enumerate(context_chunks):
        context_text += f"[CHUNK {i+1}] (Page {chunk.metadata.get('page', 'unknown')}): {chunk.page_content}\n\n"
    
    # Create prompt
    prompt = PromptTemplate(
        input_variables=["question", "context"],
        template=RAG_PROMPT_TEMPLATE
    )
    
    # Create modern chain using LCEL
    rag_chain = (
        {"question": RunnablePassthrough(), "context": lambda _: context_text}
        | prompt
        | get_llm()
        | StrOutputParser()
    )
    
    # Count tokens for the prompt
    prompt_text = RAG_PROMPT_TEMPLATE.format(question=user_message, context=context_text)
    prompt_tokens = count_tokens(prompt_text)
    cost_tracking["chat"]["input_tokens"] = prompt_tokens
    cost_tracking["chat"]["input_cost"] = calculate_cost(prompt_tokens, model="gpt-4o-mini", is_input=True)
    
    # Generate response
    response = rag_chain.invoke(user_message)
    
    # Count tokens for the response
    response_tokens = count_tokens(response)
    cost_tracking["chat"]["output_tokens"] = response_tokens
    cost_tracking["chat"]["output_cost"] = calculate_cost(response_tokens, model="gpt-4o-mini", is_input=False)
    
    # Calculate total cost
    cost_tracking["total_cost"] = (
        cost_tracking["embedding"]["cost"] + 
        cost_tracking["chat"]["input_cost"] + 
        cost_tracking["chat"]["output_cost"]
    )
    
    return {
        "answer": response,
        "citations": citations,
        "embedding_type": embedding_type,
        "cost": cost_tracking
    }

# Mount static files for the frontend
app.mount("/", StaticFiles(directory="static", html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port="$PORT", reload=True) 