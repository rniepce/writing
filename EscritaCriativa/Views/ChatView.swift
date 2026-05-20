import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @Query private var allChunks: [BookChunk]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var input = ""
    @State private var isLoading = false
    @State private var useRAG = false
    @State private var streamingText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if messages.isEmpty && !isLoading {
                        emptyState
                    } else {
                        messageList
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.captionSerif)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.xs)
                }

                inputBar
            }
            .paperBackground()
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar conversa") { clearChat() }
                        .foregroundStyle(Color.accentInk)
                        .font(.calloutSerif)
                        .disabled(messages.isEmpty)
                }
            }
        }
    }

    // MARK: - Lists & bubbles

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(messages) { msg in
                        MessageBubble(role: msg.role, content: msg.content)
                            .id(msg.id)
                    }
                    if isLoading && !streamingText.isEmpty {
                        MessageBubble(role: "assistant", content: streamingText + "▌")
                            .id("streaming")
                    } else if isLoading {
                        ThinkingBubble()
                            .id("thinking")
                    }
                }
                .padding(Spacing.md)
            }
            .onChange(of: streamingText) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
            .onChange(of: messages.count) {
                proxy.scrollTo(messages.last?.id, anchor: .bottom)
            }
            .onChange(of: isLoading) {
                if isLoading { proxy.scrollTo("thinking", anchor: .bottom) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.bottom, Spacing.xs)
                    Text("Comece pelo que está te travando")
                        .font(.title2Serif)
                        .foregroundStyle(Color.inkPrimary)
                    Text("Pergunte sobre uma cena, um personagem,\num ritmo que não está funcionando.")
                        .font(.captionSerif)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, Spacing.xl)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("EXEMPLOS")
                        .font(.captionMono)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, Spacing.xs)

                    ForEach(examplePrompts, id: \.self) { prompt in
                        Button {
                            input = prompt
                        } label: {
                            HStack {
                                Text(prompt)
                                    .font(.bodySerif)
                                    .foregroundStyle(Color.inkPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: Spacing.xs)
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentSoft)
                            }
                            .paperCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    private let examplePrompts: [String] = [
        "Como abrir uma cena sem cair no clichê?",
        "Me dê 3 maneiras de mostrar raiva sem dizer 'estava com raiva'.",
        "Qual a função do parágrafo de abertura num conto?",
        "Como evitar adjetivos vazios em descrição?",
    ]

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 0) {
            if appState.pendingChatContext != nil {
                attachmentChip
            }

            if useRAG {
                ragBanner
            }

            HStack(alignment: .bottom, spacing: Spacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { useRAG.toggle() }
                } label: {
                    Image(systemName: useRAG ? "books.vertical.fill" : "books.vertical")
                        .font(.title3)
                        .foregroundStyle(useRAG ? Color.accentInk : Color.inkSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(useRAG ? "Desligar consulta aos livros" : "Ligar consulta aos livros")

                TextField("O que você quer entender melhor?", text: $input, axis: .vertical)
                    .font(.bodySerif)
                    .tint(Color.accentInk)
                    .lineLimit(1...5)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(
                        RoundedRectangle(cornerRadius: Corner.md)
                            .fill(Color.paperRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Corner.md)
                            .strokeBorder(Color.inkDivider, lineWidth: 0.5)
                    )

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? Color.accentInk : Color.inkTertiary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Color.paperSecondary
                    .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.inkDivider), alignment: .top)
            )
        }
    }

    private var ragBanner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "books.vertical.fill")
                .font(.caption)
            Text(allChunks.isEmpty
                 ? "Importe PDFs na aba Livros pra ativar a consulta."
                 : "Consultando \(allChunks.count) trechos dos seus livros.")
                .font(.captionSerifSmall)
            Spacer()
        }
        .foregroundStyle(Color.accentInk)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.accentInk.opacity(0.08))
    }

    private var attachmentChip: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "paperclip")
                .font(.caption)
                .foregroundStyle(Color.accentInk)
            VStack(alignment: .leading, spacing: 0) {
                Text(appState.pendingChatContextLabel ?? "Trecho do Caderno")
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text("\(wordCount(appState.pendingChatContext ?? "")) palavras anexadas")
                    .font(.captionMono)
                    .foregroundStyle(Color.inkTertiary)
            }
            Spacer()
            Button {
                appState.clearChatAttachment()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.inkTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.accentInk.opacity(0.08))
    }

    private func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Send

    private func send() async {
        let userText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        input = ""
        errorMessage = nil
        isLoading = true
        streamingText = ""

        let historySnapshot = messages
        let userMsg = ChatMessage(role: "user", content: userText)
        context.insert(userMsg)

        var ragContext: String? = nil
        if useRAG && !allChunks.isEmpty {
            let retrieved = RAGService.retrieve(query: userText, from: allChunks)
            if !retrieved.isEmpty {
                ragContext = RAGService.buildContext(from: retrieved)
            }
        }

        // Captura e consome o attachment do Caderno (se houver).
        let notesContext = appState.pendingChatContext

        do {
            for try await token in DeepSeekService.shared.stream(
                userMessage: userText,
                history: historySnapshot,
                ragContext: ragContext,
                notesContext: notesContext
            ) {
                streamingText += token
            }

            let assistantMsg = ChatMessage(role: "assistant", content: streamingText)
            context.insert(assistantMsg)
            try? context.save()
            streamingText = ""

            // Sucesso: trecho anexado já cumpriu sua função.
            if notesContext != nil {
                appState.clearChatAttachment()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func clearChat() {
        messages.forEach { context.delete($0) }
        try? context.save()
    }
}

// MARK: - Bubbles

struct MessageBubble: View {
    let role: String
    let content: String

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 56) }

            Text(content)
                .font(.bodySerif)
                .foregroundStyle(isUser ? Color.paperPrimary : Color.inkPrimary)
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                        .fill(isUser ? Color.accentInk : Color.paperRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                        .strokeBorder(isUser ? Color.clear : Color.inkDivider, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(isUser ? 0 : 0.04), radius: 4, x: 0, y: 1)

            if !isUser { Spacer(minLength: 56) }
        }
    }
}

private struct ThinkingBubble: View {
    @State private var phase: Int = 0
    let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("Pensando")
                .font(.bodySerif)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.inkSecondary)
                        .frame(width: 4, height: 4)
                        .opacity(phase == i ? 1 : 0.3)
                }
            }
        }
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                .fill(Color.paperRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                .strokeBorder(Color.inkDivider, lineWidth: 0.5)
        )
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
