# Docling Chunking Reference

This reference covers document chunking for RAG pipelines, including HierarchicalChunker and HybridChunker implementations.

## Table of Contents

- [Overview](#overview)
- [BaseChunker Interface](#basechunker-interface)
- [HierarchicalChunker](#hierarchicalchunker)
- [HybridChunker](#hybridchunker)
- [Chunk Metadata](#chunk-metadata)
- [RAG Integration Patterns](#rag-integration-patterns)
- [Advanced Usage](#advanced-usage)

## Overview

Docling chunkers operate directly on `DoclingDocument` objects, creating structure-aware chunks with rich metadata. This approach preserves document hierarchy and context better than simple text splitting.

### Two Approaches

1. **Native chunkers** (this reference): Operate on `DoclingDocument` objects
2. **Post-processing**: Export to Markdown, then use external splitters

Native chunkers are recommended for RAG applications requiring document structure preservation.

## BaseChunker Interface

All chunkers implement the `BaseChunker` interface:

```python
from docling.chunking import BaseChunker, BaseChunk
from docling_core.types.doc import DoclingDocument

class BaseChunker:
    def chunk(self, dl_doc: DoclingDocument, **kwargs) -> Iterator[BaseChunk]:
        """Generate chunks from document."""
        ...

    def contextualize(self, chunk: BaseChunk) -> str:
        """Serialize chunk with metadata for embedding."""
        ...
```

### BaseChunk

Each chunk contains:

- `text`: The chunk text content
- `meta`: Metadata (headers, captions, page numbers, etc.)
- `path`: Document element path

## HierarchicalChunker

Structure-aware chunker that creates one chunk per document element (paragraph, table, etc.), preserving document hierarchy.

### Basic Usage

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HierarchicalChunker

# Convert document
converter = DocumentConverter()
result = converter.convert("document.pdf")

# Chunk document
chunker = HierarchicalChunker()
chunks = list(chunker.chunk(result.document))

print(f"Created {len(chunks)} chunks")

for chunk in chunks[:3]:
    print(f"\nChunk text: {chunk.text[:100]}...")
    print(f"Metadata: {chunk.meta}")
```

### Options

```python
from docling.chunking import HierarchicalChunker

chunker = HierarchicalChunker(
    merge_list_items=True  # Merge consecutive list items (default: True)
)
```

### Chunk Iteration

```python
for i, chunk in enumerate(chunker.chunk(result.document)):
    # Access chunk data
    text = chunk.text
    meta = chunk.meta

    # Access metadata fields
    page_num = meta.page if hasattr(meta, 'page') else None
    headings = meta.headings if hasattr(meta, 'headings') else []
    doc_items = meta.doc_items if hasattr(meta, 'doc_items') else []

    print(f"Chunk {i}: page {page_num}, {len(text)} chars")
```

### Contextualization

Add metadata context to chunk text for embedding:

```python
for chunk in chunker.chunk(result.document):
    # Plain text
    plain_text = chunk.text

    # Text with metadata context
    contextualized = chunker.contextualize(chunk)

    print(f"Plain: {plain_text[:50]}")
    print(f"Contextualized: {contextualized[:50]}")
```

## HybridChunker

Advanced chunker combining hierarchical structure with token-aware splitting and merging.

### Installation

```bash
# For HuggingFace tokenizers
pip install 'docling-core[chunking]'

# For OpenAI tokenizers (tiktoken)
pip install 'docling-core[chunking-openai]'
```

### Basic Usage

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HybridChunker
from transformers import AutoTokenizer

# Convert document
converter = DocumentConverter()
result = converter.convert("document.pdf")

# Initialize chunker with tokenizer
tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")

chunker = HybridChunker(
    tokenizer=tokenizer,
    max_tokens=512,
    merge_peers=True
)

# Generate chunks
chunks = list(chunker.chunk(result.document))

print(f"Created {len(chunks)} chunks with max {chunker.max_tokens} tokens each")
```

### Configuration Options

```python
from docling.chunking import HybridChunker
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("bert-base-uncased")

chunker = HybridChunker(
    tokenizer=tokenizer,
    max_tokens=512,           # Maximum tokens per chunk
    merge_peers=True,         # Merge undersized consecutive chunks (default: True)
    merge_list_items=True     # Merge list items (default: True)
)
```

### Token-Aware Processing

HybridChunker performs two passes:

1. **Split pass**: Splits oversized chunks to respect `max_tokens`
2. **Merge pass**: Merges undersized consecutive chunks with same headers/captions

```python
# Disable merge pass for fixed-size chunks
chunker = HybridChunker(
    tokenizer=tokenizer,
    max_tokens=256,
    merge_peers=False  # No merging, strict token limits
)
```

### OpenAI Tokenizer

```python
from docling.chunking import HybridChunker
import tiktoken

# Use OpenAI tokenizer
encoding = tiktoken.get_encoding("cl100k_base")  # GPT-4 encoding

chunker = HybridChunker(
    tokenizer=encoding,
    max_tokens=1024
)
```

## Chunk Metadata

### DocMeta Structure

Chunks from HierarchicalChunker and HybridChunker use `DocMeta`:

```python
from docling.chunking import HierarchicalChunker

chunker = HierarchicalChunker()
chunks = list(chunker.chunk(doc))

for chunk in chunks:
    meta = chunk.meta

    # Common fields
    headings = meta.headings        # List of parent headings
    captions = meta.captions        # Associated captions
    page = meta.page                # Page number
    doc_items = meta.doc_items      # Source document items
```

### Accessing Metadata

```python
for chunk in chunks:
    # Export metadata as dict
    meta_dict = chunk.meta.export_json_dict()

    print(f"Text: {chunk.text[:50]}")
    print(f"Page: {meta_dict.get('page')}")
    print(f"Headings: {meta_dict.get('headings', [])}")
    print(f"Captions: {meta_dict.get('captions', [])}")
    print()
```

### Custom Metadata Serialization

```python
def format_chunk_with_context(chunk):
    """Format chunk with metadata for embedding."""
    meta = chunk.meta.export_json_dict()

    # Build context string
    context_parts = []

    # Add headings hierarchy
    if meta.get('headings'):
        context_parts.append("Section: " + " > ".join(meta['headings']))

    # Add page number
    if meta.get('page'):
        context_parts.append(f"Page {meta['page']}")

    # Add captions
    if meta.get('captions'):
        context_parts.append("Captions: " + ", ".join(meta['captions']))

    # Combine context with text
    if context_parts:
        return " | ".join(context_parts) + "\n\n" + chunk.text
    else:
        return chunk.text

# Use with chunks
for chunk in chunks:
    formatted = format_chunk_with_context(chunk)
    # Send to embedding model
```

## RAG Integration Patterns

### LangChain Integration

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HybridChunker
from transformers import AutoTokenizer
from langchain_core.documents import Document

# Convert and chunk
converter = DocumentConverter()
result = converter.convert("document.pdf")

tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
chunker = HybridChunker(tokenizer=tokenizer, max_tokens=512)
chunks = list(chunker.chunk(result.document))

# Create LangChain documents
langchain_docs = [
    Document(
        page_content=chunk.text,
        metadata=chunk.meta.export_json_dict()
    )
    for chunk in chunks
]

# Use with vector store
from langchain_community.vectorstores import FAISS
from langchain_community.embeddings import HuggingFaceEmbeddings

embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
vectorstore = FAISS.from_documents(langchain_docs, embeddings)
```

### LlamaIndex Integration

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HybridChunker
from transformers import AutoTokenizer
from llama_index.core import Document, VectorStoreIndex
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

# Convert and chunk
converter = DocumentConverter()
result = converter.convert("document.pdf")

tokenizer = AutoTokenizer.from_pretrained("BAAI/bge-small-en-v1.5")
chunker = HybridChunker(tokenizer=tokenizer, max_tokens=512)
chunks = list(chunker.chunk(result.document))

# Create LlamaIndex documents
llama_docs = [
    Document(
        text=chunk.text,
        metadata=chunk.meta.export_json_dict()
    )
    for chunk in chunks
]

# Create index
embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-small-en-v1.5")
index = VectorStoreIndex.from_documents(llama_docs, embed_model=embed_model)
```

### Custom RAG Pipeline

```python
from docling.document_converter import DocumentConverter
from docling.chunking import HybridChunker
from transformers import AutoTokenizer, AutoModel
import torch

# Convert and chunk
converter = DocumentConverter()
result = converter.convert("document.pdf")

tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
chunker = HybridChunker(tokenizer=tokenizer, max_tokens=256)
chunks = list(chunker.chunk(result.document))

# Load embedding model
model = AutoModel.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")

def embed_chunks(chunks):
    """Generate embeddings for chunks."""
    embeddings = []

    for chunk in chunks:
        # Contextualize chunk
        text = chunker.contextualize(chunk)

        # Tokenize
        inputs = tokenizer(text, return_tensors="pt", padding=True, truncation=True)

        # Generate embedding
        with torch.no_grad():
            outputs = model(**inputs)
            embedding = outputs.last_hidden_state.mean(dim=1).squeeze().numpy()

        embeddings.append({
            "text": chunk.text,
            "embedding": embedding,
            "metadata": chunk.meta.export_json_dict()
        })

    return embeddings

# Create embeddings
chunk_embeddings = embed_chunks(chunks)
```

## Advanced Usage

### Multi-Document Chunking

```python
from pathlib import Path
from docling.document_converter import DocumentConverter
from docling.chunking import HybridChunker
from transformers import AutoTokenizer

converter = DocumentConverter()
tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
chunker = HybridChunker(tokenizer=tokenizer, max_tokens=512)

# Process multiple documents
doc_paths = list(Path("documents/").glob("*.pdf"))

all_chunks = []
for doc_path in doc_paths:
    result = converter.convert(doc_path)
    chunks = list(chunker.chunk(result.document))

    # Add document source to metadata
    for chunk in chunks:
        meta_dict = chunk.meta.export_json_dict()
        meta_dict["source_file"] = str(doc_path)
        all_chunks.append({
            "text": chunk.text,
            "metadata": meta_dict
        })

print(f"Total chunks from {len(doc_paths)} documents: {len(all_chunks)}")
```

### Filtering Chunks

```python
# Filter out small chunks
MIN_CHUNK_SIZE = 50

filtered_chunks = [
    chunk for chunk in chunks
    if len(chunk.text.strip()) >= MIN_CHUNK_SIZE
]

# Filter by metadata
def has_meaningful_content(chunk):
    """Filter out chunks with just headers or empty content."""
    text = chunk.text.strip()
    meta = chunk.meta.export_json_dict()

    # Skip if too short
    if len(text) < 20:
        return False

    # Skip if only whitespace or punctuation
    if not any(c.isalnum() for c in text):
        return False

    return True

meaningful_chunks = [c for c in chunks if has_meaningful_content(c)]
```

### Custom Chunking Strategy

```python
from docling.chunking import BaseChunker, BaseChunk, BaseMeta
from docling_core.types.doc import DoclingDocument
from typing import Iterator

class CustomChunker(BaseChunker):
    """Custom chunker that groups chunks by page."""

    def __init__(self, chunks_per_page: int = 1):
        self.chunks_per_page = chunks_per_page

    def chunk(self, dl_doc: DoclingDocument, **kwargs) -> Iterator[BaseChunk]:
        """Generate chunks grouped by page."""
        # Group items by page
        pages = {}
        for item, _ in dl_doc.iterate_items():
            if hasattr(item, 'prov') and item.prov:
                page_num = item.prov[0].page
                if page_num not in pages:
                    pages[page_num] = []
                pages[page_num].append(item)

        # Create chunks
        for page_num, items in sorted(pages.items()):
            text = " ".join(item.text for item in items if hasattr(item, 'text'))

            meta = BaseMeta()
            meta.page = page_num

            yield BaseChunk(text=text, meta=meta)

    def contextualize(self, chunk: BaseChunk) -> str:
        """Add page context."""
        page = chunk.meta.page if hasattr(chunk.meta, 'page') else None
        if page:
            return f"[Page {page}]\n{chunk.text}"
        return chunk.text

# Use custom chunker
custom_chunker = CustomChunker()
custom_chunks = list(custom_chunker.chunk(result.document))
```

### Chunk Size Analysis

```python
from collections import Counter

def analyze_chunks(chunks, tokenizer=None):
    """Analyze chunk statistics."""
    char_lengths = [len(chunk.text) for chunk in chunks]

    if tokenizer:
        token_counts = [
            len(tokenizer.encode(chunk.text))
            for chunk in chunks
        ]
    else:
        # Approximate with word count
        token_counts = [len(chunk.text.split()) for chunk in chunks]

    print(f"Total chunks: {len(chunks)}")
    print(f"\nCharacter counts:")
    print(f"  Min: {min(char_lengths)}")
    print(f"  Max: {max(char_lengths)}")
    print(f"  Mean: {sum(char_lengths) / len(char_lengths):.1f}")
    print(f"  Median: {sorted(char_lengths)[len(char_lengths)//2]}")

    print(f"\nToken counts:")
    print(f"  Min: {min(token_counts)}")
    print(f"  Max: {max(token_counts)}")
    print(f"  Mean: {sum(token_counts) / len(token_counts):.1f}")
    print(f"  Median: {sorted(token_counts)[len(token_counts)//2]}")

    # Distribution
    bins = [0, 50, 100, 256, 512, 1024, float('inf')]
    bin_labels = ["0-50", "50-100", "100-256", "256-512", "512-1024", "1024+"]
    distribution = Counter()

    for count in token_counts:
        for i, (low, high) in enumerate(zip(bins[:-1], bins[1:])):
            if low <= count < high:
                distribution[bin_labels[i]] += 1
                break

    print(f"\nToken distribution:")
    for label in bin_labels:
        print(f"  {label}: {distribution[label]}")

# Analyze chunks
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
analyze_chunks(chunks, tokenizer)
```

### Combining Chunkers

```python
# Use HierarchicalChunker, then post-process with token limits
from docling.chunking import HierarchicalChunker
from transformers import AutoTokenizer

# Initial chunking
hier_chunker = HierarchicalChunker()
base_chunks = list(hier_chunker.chunk(result.document))

# Token-aware refinement
tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
max_tokens = 512

refined_chunks = []
for chunk in base_chunks:
    tokens = tokenizer.encode(chunk.text)

    if len(tokens) <= max_tokens:
        refined_chunks.append(chunk)
    else:
        # Split oversized chunk
        # (simplified - real implementation would preserve metadata)
        sentences = chunk.text.split('. ')
        current_text = ""

        for sentence in sentences:
            test_text = current_text + sentence + '. '
            if len(tokenizer.encode(test_text)) <= max_tokens:
                current_text = test_text
            else:
                if current_text:
                    refined_chunks.append(BaseChunk(text=current_text, meta=chunk.meta))
                current_text = sentence + '. '

        if current_text:
            refined_chunks.append(BaseChunk(text=current_text, meta=chunk.meta))
```
