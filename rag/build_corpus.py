"""
Build corpus from text files in rag/papers/ directory.
Embeds documents using OpenAI text-embedding-3-small and stores in ChromaDB.
"""

import os
import re
from pathlib import Path
from typing import List, Tuple
import chromadb
from chromadb.config import Settings
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# Initialize OpenAI client (only if API key available)
def get_openai_client():
    """Get OpenAI client if API key is available."""
    api_key = os.getenv("OPENAI_API_KEY")
    if api_key:
        return OpenAI(api_key=api_key)
    return None

# Initialize ChromaDB (persistent storage)
chroma_client = chromadb.PersistentClient(
    path="./rag/chroma_db",
    settings=Settings(anonymized_telemetry=False)
)

# Get or create collection
collection = chroma_client.get_or_create_collection(
    name="flareweather_papers",
    metadata={"description": "Research papers and medical literature for FlareWeather"}
)


def clean_text(text: str) -> str:
    """Clean and normalize text."""
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove special characters that might interfere
    text = text.strip()
    return text


def split_into_paragraphs(text: str, min_length: int = 100) -> List[str]:
    """
    Split text into paragraphs and filter out very short ones.
    
    Args:
        text: Input text to split
        min_length: Minimum length for a paragraph to be included
        
    Returns:
        List of paragraph chunks
    """
    # Split by double newlines or single newline followed by capital letter
    paragraphs = re.split(r'\n\n+|\n(?=[A-Z])', text)
    
    # Filter and clean paragraphs
    filtered = []
    for para in paragraphs:
        cleaned = clean_text(para)
        if len(cleaned) >= min_length:
            filtered.append(cleaned)
    
    return filtered


def embed_text(text: str) -> List[float]:
    """
    Embed a single text chunk using OpenAI's text-embedding-3-small.
    
    Args:
        text: Text to embed
        
    Returns:
        Embedding vector
    """
    client = get_openai_client()
    if not client:
        raise ValueError("OpenAI API key not found")
    
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding


def process_file(file_path: Path) -> List[Tuple[str, str, str]]:
    """
    Process a single text file into chunks.
    
    Args:
        file_path: Path to the text file
        
    Returns:
        List of tuples: (chunk_text, filename, chunk_id)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        filename = file_path.name
        paragraphs = split_into_paragraphs(content)
        
        chunks = []
        for idx, para in enumerate(paragraphs):
            chunk_id = f"{filename}_{idx}"
            chunks.append((para, filename, chunk_id))
        
        return chunks
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return []


def build_corpus():
    """
    Build corpus from all .txt files in rag/papers/ directory.
    """
    papers_dir = Path("rag/papers")
    
    if not papers_dir.exists():
        print("⚠️  Warning: rag/papers/ directory does not exist!")
        print("   Please add .txt files like pressure-arthritis.txt, temperature-migraine.txt, etc.")
        return
    
    # Get all .txt files
    txt_files = list(papers_dir.glob("*.txt"))
    
    if not txt_files:
        print("⚠️  Warning: No .txt files found in rag/papers/")
        print("   Please add .txt files like pressure-arthritis.txt, temperature-migraine.txt, etc.")
        return
    
    print(f"Found {len(txt_files)} text file(s)")
    
    all_chunks = []
    all_texts = []
    all_metadatas = []
    all_ids = []
    
    for file_path in txt_files:
        print(f"Processing: {file_path.name}")
        chunks = process_file(file_path)
        
        for chunk_text, filename, chunk_id in chunks:
            all_chunks.append((chunk_text, filename, chunk_id))
            all_texts.append(chunk_text)
            all_metadatas.append({"source": filename})
            all_ids.append(chunk_id)
    
    if not all_texts:
        print("⚠️  No valid chunks found in files")
        return
    
    print(f"Total chunks: {len(all_texts)}")
    
    # Check for OpenAI client
    client = get_openai_client()
    if not client:
        print("❌ OpenAI API key not found. Cannot generate embeddings.")
        print("   Please add OPENAI_API_KEY to .env file")
        return
    
    print("Generating embeddings...")
    
    # Generate embeddings in batches
    embeddings = []
    batch_size = 100
    
    for i in range(0, len(all_texts), batch_size):
        batch = all_texts[i:i + batch_size]
        print(f"  Embedding batch {i//batch_size + 1}/{(len(all_texts)-1)//batch_size + 1}...")
        
        # Embed batch
        response = client.embeddings.create(
            model="text-embedding-3-small",
            input=batch
        )
        
        batch_embeddings = [item.embedding for item in response.data]
        embeddings.extend(batch_embeddings)
    
    print("Storing in ChromaDB...")
    
    # Clear existing collection (optional - comment out if you want to add incrementally)
    # collection.delete()
    
    # Add to ChromaDB
    collection.add(
        embeddings=embeddings,
        documents=all_texts,
        metadatas=all_metadatas,
        ids=all_ids
    )
    
    print(f"✅ Successfully stored {len(all_texts)} chunks in ChromaDB")
    print(f"   Collection: {collection.name}")
    print(f"   Total documents: {collection.count()}")


if __name__ == "__main__":
    build_corpus()

