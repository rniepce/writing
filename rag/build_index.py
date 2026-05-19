"""
Chunks the raw text in rag/chunks/raw/, embeds each chunk with a local
sentence-transformers model, and persists everything to a ChromaDB collection
at rag/index/chroma.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import chromadb
from chromadb.config import Settings
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction
from langchain_text_splitters import RecursiveCharacterTextSplitter

ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "chunks" / "raw"
INDEX_DIR = ROOT / "index" / "chroma"
INDEX_DIR.mkdir(parents=True, exist_ok=True)
BOOKS_JSON = ROOT / "books.json"

COLLECTION = "writing_books"
MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
CHUNK_SIZE = 900
CHUNK_OVERLAP = 150


PAGE_RE = re.compile(r"\[\[page (\d+)\]\]")


def parse_chunks(text: str, book_id: str, splitter: RecursiveCharacterTextSplitter):
    """Yield (chunk_text, metadata_dict) tuples.

    For PDFs the raw text contains `[[page N]]` markers (added by extract.py),
    so we propagate the page number into the metadata when available.
    """
    raw_chunks = splitter.split_text(text)
    for idx, chunk in enumerate(raw_chunks):
        m = PAGE_RE.search(chunk)
        page = int(m.group(1)) if m else None
        # strip page markers from the stored chunk
        clean = PAGE_RE.sub("", chunk).strip()
        if not clean:
            continue
        meta = {"book_id": book_id, "chunk_idx": idx}
        if page is not None:
            meta["page"] = page
        yield clean, meta


def main() -> int:
    books = {b["id"]: b for b in json.loads(BOOKS_JSON.read_text())}

    raw_files = sorted(RAW_DIR.glob("*.txt"))
    if not raw_files:
        print(f"No raw text in {RAW_DIR}. Run extract.py first.")
        return 1

    print(f"Loading embedding model: {MODEL_NAME}")
    embed_fn = SentenceTransformerEmbeddingFunction(model_name=MODEL_NAME)

    client = chromadb.PersistentClient(
        path=str(INDEX_DIR), settings=Settings(anonymized_telemetry=False)
    )
    # rebuild from scratch so the index always matches the raw files
    try:
        client.delete_collection(COLLECTION)
    except Exception:
        pass
    collection = client.create_collection(COLLECTION, embedding_function=embed_fn)

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        separators=["\n\n", "\n", ". ", " ", ""],
    )

    total = 0
    for raw in raw_files:
        book_id = raw.stem
        book = books.get(book_id, {})
        text = raw.read_text(encoding="utf-8")
        ids: list[str] = []
        docs: list[str] = []
        metas: list[dict] = []
        for chunk_text, meta in parse_chunks(text, book_id, splitter):
            meta["title"] = book.get("title", book_id)
            meta["author"] = book.get("author", "")
            ids.append(f"{book_id}:{meta['chunk_idx']}")
            docs.append(chunk_text)
            metas.append(meta)
        if not docs:
            print(f"= {book_id}: no chunks produced, skipping")
            continue
        # add in batches to keep memory bounded
        BATCH = 256
        for i in range(0, len(docs), BATCH):
            collection.add(
                ids=ids[i : i + BATCH],
                documents=docs[i : i + BATCH],
                metadatas=metas[i : i + BATCH],
            )
        total += len(docs)
        print(f"+ {book_id}: indexed {len(docs)} chunks")

    print(f"\nDone. Total chunks indexed: {total}")
    print(f"Persisted to: {INDEX_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
