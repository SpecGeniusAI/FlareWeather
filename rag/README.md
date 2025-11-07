# RAG System for FlareWeather

This directory contains the Retrieval-Augmented Generation (RAG) system for FlareWeather's AI insights.

## Setup

### 1. Install Dependencies

Make sure `chromadb` is installed:
```bash
pip install chromadb
```

### 2. Add Research Papers

**⚠️ IMPORTANT: Add your research papers to `rag/papers/` directory**

Create text files with relevant medical/weather research. Examples:
- `pressure-arthritis.txt` - Research on barometric pressure and arthritis
- `temperature-migraine.txt` - Research on temperature and migraines
- `humidity-respiratory.txt` - Research on humidity and respiratory symptoms
- `wind-allergies.txt` - Research on wind patterns and allergies

Each file should contain relevant research text in plain `.txt` format.

### 3. Build the Corpus

Run the build script to embed all papers and store in ChromaDB:

```bash
python rag/build_corpus.py
```

This will:
- Read all `.txt` files from `rag/papers/`
- Split them into paragraph chunks
- Generate embeddings using OpenAI `text-embedding-3-small`
- Store in local ChromaDB at `rag/chroma_db/`

### 4. Test the Query System

Test the RAG query system:

```bash
python rag/query.py
```

## Usage

The RAG system is automatically integrated into the `/analyze` endpoint:

1. When a request comes in, it extracts the strongest weather factor and most common symptom
2. Builds a query like: "How do [weather factor] affect [symptom]?"
3. Retrieves top 3 relevant document chunks
4. Enhances the AI prompt with research context
5. Returns insights with citations

## Files

- `build_corpus.py` - Builds the vector database from text files
- `query.py` - Queries the vector database for relevant chunks
- `papers/` - Directory for your research text files (add files here!)
- `chroma_db/` - ChromaDB storage (created automatically)

## Notes

- The corpus needs to be rebuilt if you add new papers
- ChromaDB stores embeddings locally (persistent)
- Each paper should be a single `.txt` file
- Paragraphs are automatically chunked (minimum 100 characters)

