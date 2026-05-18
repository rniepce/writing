# Escrita Criativa — iOS App

App para iPhone que funciona como companheiro de escrita criativa de ficção.

## Funcionalidades

- **Dica do Dia** — uma dica de craft por dia, curada por você
- **Chat** — conversa com DeepSeek sobre técnicas de escrita
- **RAG on-device** — importa PDFs de livros sobre escrita e consulta localmente (BM25)
- **Biblioteca** — gerencie seus livros de referência

## Setup

### Pré-requisitos

- Xcode 15+
- iOS 17+ (target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Chave de API do [DeepSeek](https://platform.deepseek.com)

### Gerar o projeto Xcode

```bash
cd writing/
xcodegen generate
open EscritaCriativa.xcodeproj
```

### Configurar a API Key

No app, vá em **Config → DeepSeek API** e insira sua chave. Ela é salva com segurança no Keychain do iPhone.

### Adicionar suas dicas

Edite `EscritaCriativa/Resources/tips_iniciais.json` antes de compilar, ou adicione novas dicas diretamente no app (em breve).

### Adicionar livros ao RAG

Na aba **Biblioteca**, toque em **+** e selecione um PDF do Files app. O app processa e indexa os trechos automaticamente no device.

## Stack

- SwiftUI + SwiftData (persistência on-device)
- PDFKit (extração de texto de PDFs)
- BM25 (busca semântica on-device, sem dependência externa)
- DeepSeek API (LLM para chat e respostas contextualizadas)
- Keychain (armazenamento seguro da API key)
