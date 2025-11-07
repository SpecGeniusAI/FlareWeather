# Research Papers Directory

⚠️ **IMPORTANT: Add your research papers here!**

## How to Add Papers

1. Create `.txt` files in this directory
2. Name them descriptively, e.g.:
   - `pressure-arthritis.txt`
   - `temperature-migraine.txt`
   - `humidity-respiratory.txt`
   - `wind-allergies.txt`
   - `barometric-pain.txt`

3. Each file should contain:
   - Relevant research text
   - Can be copied from research papers, articles, or medical literature
   - Plain text format (no formatting needed)
   - Will be automatically chunked into paragraphs

## Example Structure

```
papers/
├── pressure-arthritis.txt     # Research on barometric pressure and arthritis
├── temperature-migraine.txt   # Research on temperature effects on migraines
├── humidity-respiratory.txt   # Research on humidity and respiratory issues
└── wind-allergies.txt         # Research on wind patterns and allergies
```

## After Adding Files

Run the build script to index them:

```bash
python rag/build_corpus.py
```

The system will automatically:
- Split files into paragraphs
- Generate embeddings
- Store in ChromaDB for fast retrieval

## Tips

- Include relevant medical research
- Focus on weather-health correlations
- Each file can be any length (will be chunked automatically)
- More files = better RAG results!

