"""
Query RAG system using ChromaDB and OpenAI embeddings.
"""

import os
from typing import List, Tuple
import chromadb
from chromadb.config import Settings
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# Initialize OpenAI client (lazy - only if API key is available)
def get_openai_client():
    """Get OpenAI client if API key is available."""
    api_key = os.getenv("OPENAI_API_KEY")
    if api_key:
        return OpenAI(api_key=api_key)
    return None

# Initialize ChromaDB (same persistent storage)
chroma_client = chromadb.PersistentClient(
    path="./rag/chroma_db",
    settings=Settings(anonymized_telemetry=False)
)

# Get collection (lazy initialization)
def get_collection():
    """Get or create the collection."""
    try:
        return chroma_client.get_collection(name="flareweather_papers")
    except:
        return None


def query_rag(question: str, k: int = 3) -> List[Tuple[str, str]]:
    """
    Query RAG system for relevant document chunks.
    
    Args:
        question: The question/query string
        k: Number of top results to return (default: 3)
        
    Returns:
        List of tuples: [(chunk_text, source_filename), ...]
        Returns empty list if collection doesn't exist or query fails
    """
    collection = get_collection()
    if collection is None:
        print("⚠️  RAG collection not found. Run build_corpus.py first.")
        return []
    
    try:
        client = get_openai_client()
        if not client:
            print("⚠️  OpenAI API key not found. RAG query requires OpenAI API key.")
            return []
        
        # Embed the question
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=question
        )
        query_embedding = response.data[0].embedding
        
        # Query ChromaDB
        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=k
        )
        
        # Extract results
        chunks = []
        if results['documents'] and len(results['documents'][0]) > 0:
            documents = results['documents'][0]
            metadatas = results['metadatas'][0] if results['metadatas'] else []
            
            for doc, metadata in zip(documents, metadatas):
                source = metadata.get('source', 'unknown') if metadata else 'unknown'
                chunks.append((doc, source))
        
        return chunks
        
    except Exception as e:
        print(f"Error querying RAG: {e}")
        return []


if __name__ == "__main__":
    # Test query
    test_question = "How does barometric pressure affect arthritis pain?"
    results = query_rag(test_question, k=3)
    
    print(f"Query: {test_question}")
    print(f"Found {len(results)} results:\n")
    
    for i, (chunk, source) in enumerate(results, 1):
        print(f"{i}. Source: {source}")
        print(f"   Text: {chunk[:200]}...")
        print()

