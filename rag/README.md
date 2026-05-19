# RAG de livros de escrita criativa

Indexa 10 livros sobre escrita (Strunk, King, Lamott, Goldberg, Prose, Gardner,
Maass, Tufte, Landon, Miell) e expõe uma CLI de busca semântica para uma LLM
consultar dicas, exemplos e regras.

## Estrutura

```
rag/
  books.json           # catálogo dos livros (id, autor, caminho, formato)
  extract.py           # extrai texto de PDF / EPUB / FB2 / AZW
  build_index.py       # chunk + embed + persist em ChromaDB
  query.py             # CLI de busca semântica
  requirements.txt
  chunks/raw/          # 1 .txt por livro (gerado por extract.py)
  index/chroma/        # banco vetorial persistente (gerado por build_index.py)
```

## Setup

```bash
pip3 install --user -r rag/requirements.txt
```

Dependências chave:
- `pdfplumber` para PDFs
- `ebooklib` + `beautifulsoup4` para EPUB
- `lxml` para FB2
- `mobi` para AZW (formato Kindle)
- `sentence-transformers` (modelo `paraphrase-multilingual-MiniLM-L12-v2`, multilíngue PT/EN, roda local, sem API key)
- `chromadb` para persistência do índice

## Build (uma vez)

```bash
python3 rag/extract.py        # ~minutos (Tufte tem 29 MB)
python3 rag/build_index.py    # chunk + embed
```

Re-rodar `extract.py` é idempotente (pula livros já extraídos). Para forçar
re-extração de um livro, apague o `.txt` correspondente em `chunks/raw/`.
`build_index.py` sempre reconstrói a coleção do zero.

## Query

```bash
# busca em todos os livros
python3 rag/query.py "como descrever emoções sem dizer o sentimento"

# top-K customizado
python3 rag/query.py "show, don't tell" --k 8

# restringir a um livro
python3 rag/query.py "estrutura de sentenças longas" --book tufte_artfulsentences

# saída JSON para outra ferramenta consumir
python3 rag/query.py "primeira frase de um capítulo" --json
```

Cada resultado vem com:
- `score` (similaridade, maior = melhor)
- `author`, `title`, `book_id`
- `page` (se for PDF)
- `text` (trecho relevante)

## IDs de livro (para usar com `--book`)

| ID | Título | Autor |
|---|---|---|
| `miell_grammar` | Grammar Workbook | Anna Miell |
| `landon_sentences` | Building Great Sentences | Brooks Landon |
| `king_onwriting` | On Writing | Stephen King |
| `goldberg_bones` | Writing Down the Bones | Natalie Goldberg |
| `lamott_birdbybird` | Bird by Bird | Anne Lamott |
| `prose_readinglikeawriter` | Reading Like a Writer | Francine Prose |
| `gardner_artoffiction` | The Art of Fiction | John Gardner |
| `maass_emotionalcraft` | The Emotional Craft of Fiction | Donald Maass |
| `tufte_artfulsentences` | Artful Sentences | Virginia Tufte |
| `strunk_elements` | The Elements of Style | William Strunk Jr. |

## Integração com uma LLM

A CLI já produz saída pronta para um prompt. Fluxo típico:

1. Usuário pergunta algo no app iOS de escrita criativa
2. Backend (ou script local) chama `query.py "pergunta" --json --k 5`
3. Resultado é injetado como contexto na chamada à LLM:

```
Você é um assistente de escrita criativa. Use os trechos abaixo, extraídos
de livros canônicos sobre o ofício, para fundamentar a resposta. Cite o autor
quando possível.

<<<
[trechos do query.py]
>>>

Pergunta: ...
```

A coleção também é consumível diretamente via API do `chromadb` se você
preferir embutir a busca em outro processo Python — ver `query.py` como
exemplo.
