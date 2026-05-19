"""
Query the writing-tips Chroma index built by build_index.py.

Usage:
    python3 rag/query.py "como descrever emoções sem dizer o sentimento"
    python3 rag/query.py "show, don't tell" --k 8
    python3 rag/query.py "estrutura de sentenças longas" --book tufte_artfulsentences

Output is plain text — each hit shows score, book, author, page (if any),
and the chunk content. Suitable to paste into an LLM prompt.

Add --json to get a machine-readable result list, e.g. for feeding directly
into another tool.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import chromadb
from chromadb.config import Settings
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

ROOT = Path(__file__).resolve().parent
INDEX_DIR = ROOT / "index" / "chroma"
COLLECTION = "writing_books"
MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


def open_collection():
    if not INDEX_DIR.exists():
        print(f"Index not found at {INDEX_DIR}. Run build_index.py first.", file=sys.stderr)
        sys.exit(2)
    embed_fn = SentenceTransformerEmbeddingFunction(model_name=MODEL_NAME)
    client = chromadb.PersistentClient(
        path=str(INDEX_DIR), settings=Settings(anonymized_telemetry=False)
    )
    return client.get_collection(COLLECTION, embedding_function=embed_fn)


def run(query: str, k: int, book: str | None) -> dict:
    collection = open_collection()
    where = {"book_id": book} if book else None
    res = collection.query(query_texts=[query], n_results=k, where=where)
    out = []
    for doc, meta, dist in zip(
        res["documents"][0], res["metadatas"][0], res["distances"][0]
    ):
        out.append(
            {
                "score": round(1 - dist, 4),  # cosine-ish similarity, higher is better
                "book_id": meta.get("book_id"),
                "title": meta.get("title"),
                "author": meta.get("author"),
                "page": meta.get("page"),
                "text": doc,
            }
        )
    return {"query": query, "results": out}


def format_human(payload: dict) -> str:
    lines = [f"Query: {payload['query']}", ""]
    for i, hit in enumerate(payload["results"], 1):
        head = f"[{i}] score={hit['score']:.3f}  {hit['author']} — {hit['title']}"
        if hit.get("page"):
            head += f"  (p.{hit['page']})"
        lines.append(head)
        lines.append(hit["text"])
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description="Query the writing-tips RAG index.")
    p.add_argument("query", help="Natural language question")
    p.add_argument("--k", type=int, default=5, help="Top-K results (default 5)")
    p.add_argument("--book", help="Restrict to a single book_id (see books.json)")
    p.add_argument("--json", action="store_true", help="Output JSON instead of text")
    args = p.parse_args()

    payload = run(args.query, args.k, args.book)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(format_human(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
