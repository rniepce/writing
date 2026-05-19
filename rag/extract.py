"""
Extracts plain text from each book in books.json and writes the result to
rag/chunks/raw/<book_id>.txt.

Supports PDF (pdfplumber), EPUB (ebooklib + BeautifulSoup), FB2 (lxml),
and AZW/MOBI (mobi package).
"""
from __future__ import annotations

import json
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOOKS_JSON = ROOT / "books.json"
RAW_DIR = ROOT / "chunks" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)


def clean_text(text: str) -> str:
    # collapse runs of whitespace but preserve paragraph breaks
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_pdf(path: Path) -> str:
    import pdfplumber

    pages: list[str] = []
    with pdfplumber.open(str(path)) as pdf:
        for i, page in enumerate(pdf.pages):
            try:
                t = page.extract_text() or ""
            except Exception as e:  # noqa: BLE001
                print(f"  ! page {i+1} extract failed: {e}", file=sys.stderr)
                t = ""
            if t:
                pages.append(f"[[page {i+1}]]\n{t}")
    return "\n\n".join(pages)


def extract_epub(path: Path) -> str:
    import ebooklib
    from bs4 import BeautifulSoup
    from ebooklib import epub

    book = epub.read_epub(str(path))
    chunks: list[str] = []
    for item in book.get_items_of_type(ebooklib.ITEM_DOCUMENT):
        soup = BeautifulSoup(item.get_content(), "lxml")
        for tag in soup(["script", "style"]):
            tag.decompose()
        text = soup.get_text(separator="\n")
        if text and text.strip():
            chunks.append(text)
    return "\n\n".join(chunks)


def extract_fb2(path: Path) -> str:
    from lxml import etree

    # FB2 is XML; strip namespaces for simpler XPath, drop binary blobs.
    tree = etree.parse(str(path))
    root = tree.getroot()
    for elem in root.iter():
        if isinstance(elem.tag, str) and "}" in elem.tag:
            elem.tag = elem.tag.split("}", 1)[1]
    for binary in root.findall(".//binary"):
        parent = binary.getparent()
        if parent is not None:
            parent.remove(binary)
    # body holds the actual narrative
    pieces: list[str] = []
    for body in root.findall(".//body"):
        text = " ".join(body.itertext())
        if text.strip():
            pieces.append(text)
    return "\n\n".join(pieces)


def extract_azw(path: Path) -> str:
    """AZW/MOBI extraction via the `mobi` package, which unpacks to HTML/EPUB."""
    import mobi

    tempdir, filepath = mobi.extract(str(path))
    try:
        out = Path(filepath)
        # mobi.extract returns either an EPUB or an HTML payload depending on the file.
        if out.suffix.lower() == ".epub":
            return extract_epub(out)
        if out.suffix.lower() in {".html", ".htm", ".xhtml"}:
            from bs4 import BeautifulSoup

            soup = BeautifulSoup(out.read_bytes(), "lxml")
            for tag in soup(["script", "style"]):
                tag.decompose()
            return soup.get_text(separator="\n")
        # fallback: walk extracted tree for HTML files
        from bs4 import BeautifulSoup

        parent = out if out.is_dir() else out.parent
        chunks: list[str] = []
        for html in sorted(parent.rglob("*.html")) + sorted(parent.rglob("*.xhtml")):
            soup = BeautifulSoup(html.read_bytes(), "lxml")
            for tag in soup(["script", "style"]):
                tag.decompose()
            chunks.append(soup.get_text(separator="\n"))
        if chunks:
            return "\n\n".join(chunks)
        raise RuntimeError(f"Unknown payload from mobi.extract: {filepath}")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


EXTRACTORS = {
    "pdf": extract_pdf,
    "epub": extract_epub,
    "fb2": extract_fb2,
    "azw": extract_azw,
    "mobi": extract_azw,
}


def main() -> int:
    books = json.loads(BOOKS_JSON.read_text())
    failed: list[str] = []
    for book in books:
        bid = book["id"]
        fmt = book["format"]
        src = Path(book["path"])
        out_path = RAW_DIR / f"{bid}.txt"
        if out_path.exists() and out_path.stat().st_size > 0:
            print(f"= {bid}: already extracted ({out_path.stat().st_size} bytes), skipping")
            continue
        if not src.exists():
            print(f"! {bid}: source not found at {src}", file=sys.stderr)
            failed.append(bid)
            continue
        print(f"+ {bid}: extracting {fmt} from {src.name}")
        try:
            extractor = EXTRACTORS[fmt]
        except KeyError:
            print(f"! {bid}: no extractor for format {fmt}", file=sys.stderr)
            failed.append(bid)
            continue
        try:
            text = extractor(src)
        except Exception as e:  # noqa: BLE001
            print(f"! {bid}: extraction failed: {e}", file=sys.stderr)
            failed.append(bid)
            continue
        text = clean_text(text)
        if not text:
            print(f"! {bid}: extracted text is empty", file=sys.stderr)
            failed.append(bid)
            continue
        out_path.write_text(text, encoding="utf-8")
        print(f"  -> {out_path} ({len(text)} chars)")
    if failed:
        print(f"\nDone with errors. Failed: {failed}", file=sys.stderr)
        return 1
    print("\nAll books extracted successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
