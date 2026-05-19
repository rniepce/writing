# Escrita Criativa — iOS App

Companheiro de escrita criativa de ficção para iPhone. Caderno, dicas diárias,
chat com IA, RAG on-device sobre livros de craft, e exemplos canônicos da
literatura que ilustram cada lição.

## Funcionalidades

- **Caderno** — escreva cenas, esboce personagens, anote ideias. Editor
  serifado, tags (Cena / Personagem / Ideia / Diário / Outro), contagem de
  palavras, auto-save. Cada nota tem um botão "Consultar livros" que roda o
  RAG sem sair do editor.
- **Hoje** — uma dica de craft por dia, curada por você. Cada dica vem com
  um botão "Ver exemplo na ficção" que abre um trecho literário canônico
  (Tolstoy, Joyce, Chekhov, Hemingway, etc.) que ilustra o princípio.
- **Chat** — conversa em streaming com DeepSeek V4 sobre técnicas de
  escrita. Toggle 📚 ativa o RAG, injetando trechos do seu acervo como
  contexto pra LLM.
- **Livros** — importe PDFs sobre o ofício; o app extrai com `PDFKit`,
  quebra em chunks e indexa via BM25 (Jaccard) no SwiftData local.
- **Ajustes** — chave da DeepSeek no Keychain, seletor entre V4 Pro
  (qualidade) e V4 Flash (latência).

## Visual

Identidade "papel + tinta": tipografia serifada (New York via `.serif`),
paleta creme/oxblood (light) e couro envelhecido/amber (dark). Definido
num único arquivo: [`EscritaCriativa/Theme/Theme.swift`](EscritaCriativa/Theme/Theme.swift).

App icon: `e` lowercase serifado em ink primary sobre paperPrimary, gerado
a partir do mesmo design system.

## Setup

### Pré-requisitos

- Xcode 15+
- iPhone com iOS 17+ (target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (opcional, só se for
  regenerar o `.xcodeproj` a partir do `project.yml`): `brew install xcodegen`
- Chave de API da [DeepSeek](https://platform.deepseek.com)

### Rodar

```bash
open EscritaCriativa.xcodeproj
```

Em **Signing & Capabilities**, escolha seu **Team**. `⌘R` no Xcode pra
instalar no iPhone.

### Configurar a API Key

Dentro do app: **Ajustes → Chave do DeepSeek → Salvar**. Vai pro Keychain
e nunca sai do device exceto na chamada à `api.deepseek.com`.

### Importar livros

Aba **Livros → +**: escolha um PDF do Files app. O app extrai texto,
chunka e indexa automaticamente. Aguarde o "Indexando…" virar
"N trechos indexados".

A pasta `rag/` na raiz do repo tem o pipeline equivalente em Python
(ChromaDB + sentence-transformers multilíngue) para indexar e consultar
os livros pelo Mac via CLI.

## Stack

- **SwiftUI + SwiftData** — UI declarativa, persistência on-device
- **PDFKit** — extração de texto dos PDFs
- **BM25/Jaccard** — busca on-device sem embeddings
- **DeepSeek API** (V4 Pro / V4 Flash) — LLM via streaming
- **Keychain** — chave de API segura

## Estrutura

```
EscritaCriativa/
  App/                EscritaCriativaApp.swift
  Models/             Book, BookChunk, ChatMessage, LiteraryExample, Note, Tip
  Services/           DeepSeek, Keychain, LiteraryExamples, PDFIngestion, RAG, Tips
  Theme/              Theme.swift  (cores, tipografia, modifiers reutilizáveis)
  Views/              Caderno, Chat, Content, Home, Library, NoteEditor,
                      LiteraryExampleSheet, Settings
  Resources/          tips_iniciais.json, literary_examples.json
  Assets.xcassets/    AppIcon

rag/                  Pipeline Python: extract.py, build_index.py, query.py
```

## Roadmap (não feito)

- Onboarding na primeira abertura
- Handoff "Pedir ao chat" do Caderno → Chat com texto selecionado
- Export de notas (markdown / PDF)
- Visualização dos favoritos da Dica do Dia
- Sync iCloud opcional do Caderno
- PDF ingestion nativa de EPUB/FB2 (hoje só PDF; converti os outros 6 do
  meu acervo via `cupsfilter`)
