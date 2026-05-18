import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @Query private var allChunks: [BookChunk]
    @Environment(\.modelContext) private var context

    @State private var input = ""
    @State private var isLoading = false
    @State private var useRAG = false
    @State private var streamingText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                inputBar
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") { clearChat() }
                        .disabled(messages.isEmpty)
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        MessageBubble(role: msg.role, content: msg.content)
                            .id(msg.id)
                    }
                    if isLoading && !streamingText.isEmpty {
                        MessageBubble(role: "assistant", content: streamingText + "▌")
                            .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: streamingText) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
            .onChange(of: messages.count) {
                proxy.scrollTo(messages.last?.id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                useRAG.toggle()
            } label: {
                Image(systemName: "books.vertical\(useRAG ? ".fill" : "")")
                    .foregroundStyle(useRAG ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            TextField("Pergunta sobre escrita...", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

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

        do {
            for try await token in DeepSeekService.shared.stream(
                userMessage: userText,
                history: historySnapshot,
                ragContext: ragContext
            ) {
                streamingText += token
            }

            let assistantMsg = ChatMessage(role: "assistant", content: streamingText)
            context.insert(assistantMsg)
            try? context.save()
            streamingText = ""
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

struct MessageBubble: View {
    let role: String
    let content: String

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            Text(content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isUser ? Color.blue : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 48) }
        }
    }
}
