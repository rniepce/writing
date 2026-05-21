import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @FocusState private var bodyFocused: Bool
    @State private var showConsultSheet = false
    @State private var showTagPicker = false
    @State private var showDeleteConfirm = false
    @State private var classifyTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    tagChip
                    titleField
                    Divider()
                        .background(Color.inkDivider)
                    bodyEditor
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }

            footerBar
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(note.updatedAt.formatted(.dateTime.day().month(.wide)))
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkTertiary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        sendToChat()
                    } label: {
                        Label("Pedir feedback ao chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .disabled(note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    ShareLink(
                        item: noteAsMarkdown,
                        subject: Text(note.displayTitle),
                        message: Text(note.tag.rawValue)
                    ) {
                        Label("Compartilhar como texto", systemImage: "square.and.arrow.up")
                    }
                    .disabled(note.title.isEmpty && note.body.isEmpty)

                    Section("Tag") {
                        ForEach(NoteTag.allCases) { tag in
                            Button {
                                note.tag = tag
                                note.wasManuallyTagged = true
                                classifyTask?.cancel()
                                touch()
                            } label: {
                                Label(
                                    tag.rawValue,
                                    systemImage: note.tag == tag ? "checkmark" : tag.symbol
                                )
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Apagar nota", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.accentInk)
                }
            }
        }
        .sheet(isPresented: $showConsultSheet) {
            ConsultBooksSheet(seedQuery: defaultConsultQuery)
        }
        .alert("Apagar nota?", isPresented: $showDeleteConfirm) {
            Button("Apagar", role: .destructive) {
                context.delete(note)
                try? context.save()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\"\(note.displayTitle)\" será apagada permanentemente.")
        }
        .toolbarBackground(Color.paperPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: note.title) { _, _ in touch() }
        .onChange(of: note.body)  { _, _ in
            touch()
            scheduleAutoClassify()
        }
        .onDisappear { classifyTask?.cancel() }
    }

    // MARK: - Subviews

    private var tagChip: some View {
        HStack(spacing: 6) {
            Image(systemName: note.tag.symbol)
                .font(.system(size: 12, weight: .medium))
            Text(note.tag.rawValue.uppercased())
                .font(.captionMono)
        }
        .foregroundStyle(Color.accentInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.accentInk.opacity(0.5), lineWidth: 0.6)
        )
    }

    private var titleField: some View {
        TextField("Título", text: $note.title, axis: .vertical)
            .font(.display(28, weight: .semibold))
            .foregroundStyle(Color.inkPrimary)
            .tint(Color.accentInk)
            .lineLimit(1...3)
    }

    private var bodyEditor: some View {
        // Usamos TextEditor com fundo transparente pra sensação de papel contínuo.
        TextEditor(text: $note.body)
            .font(.bodySerif)
            .foregroundStyle(Color.inkPrimary)
            .tint(Color.accentInk)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 320)
            .focused($bodyFocused)
            .overlay(alignment: .topLeading) {
                if note.body.isEmpty {
                    Text("Comece uma cena, anote uma ideia…")
                        .font(.bodySerif)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
    }

    private var footerBar: some View {
        HStack(spacing: Spacing.md) {
            Text("\(note.wordCount) palavras")
                .font(.captionMono)
                .foregroundStyle(Color.inkSecondary)

            Spacer()

            Button {
                showConsultSheet = true
            } label: {
                Label("Consultar acervo", systemImage: "books.vertical")
                    .font(.calloutSerif)
            }
            .buttonStyle(OutlineInkButtonStyle())

            Button {
                bodyFocused.toggle()
            } label: {
                Image(systemName: bodyFocused ? "keyboard.chevron.compact.down" : "pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Color.paperSecondary
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.inkDivider), alignment: .top)
        )
    }

    // MARK: - Helpers

    /// Texto que preenchemos como ponto de partida na busca da consulta.
    /// Usa o último parágrafo do corpo, se houver; senão o título.
    private var defaultConsultQuery: String {
        let paragraphs = note.body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        if let last = paragraphs.last, last.trimmingCharacters(in: .whitespaces).count > 4 {
            return String(last.prefix(140))
        }
        return note.title
    }

    private func touch() {
        note.updatedAt = Date()
        try? context.save()
    }

    /// Anexa o corpo da nota como contexto pra próxima mensagem do Chat
    /// e troca pra aba Chat. O AppState carrega o handoff.
    private func sendToChat() {
        appState.pendingChatContext = note.body
        appState.pendingChatContextLabel = note.displayTitle
        appState.selectedTab = .chat
        dismiss()
    }

    /// Markdown universal pra exportar a nota — title + body, sem ruído.
    /// Útil pra colar em editores, mandar por email, salvar em Files, etc.
    private var noteAsMarkdown: String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = note.body
        if title.isEmpty {
            return body
        }
        return "# \(title)\n\n\(body)"
    }

    /// Auto-classifica a nota via DeepSeek depois de N segundos sem digitação.
    /// Só roda se:
    ///  - usuário ainda não escolheu tag manualmente
    ///  - corpo tem ao menos 80 caracteres (texto curto demais não classifica bem)
    ///  - há chave da DeepSeek configurada (silenciosamente falha se não)
    /// Cancela job anterior se ainda estiver pendente — debouncing.
    private func scheduleAutoClassify() {
        classifyTask?.cancel()
        guard !note.wasManuallyTagged,
              note.body.count >= 80
        else { return }
        let snapshot = note.body
        classifyTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            if Task.isCancelled { return }
            // Só prossegue se o body ainda é o mesmo (não rodou outra edição)
            guard note.body == snapshot, !note.wasManuallyTagged else { return }
            do {
                if let tag = try await DeepSeekService.shared.classify(text: snapshot),
                   note.tag != tag,
                   !note.wasManuallyTagged
                {
                    note.tag = tag
                    try? context.save()
                }
            } catch {
                // Auto-tag é best-effort. Falhas silenciosas (sem chave, sem
                // internet, modelo cuspiu lixo) não devem incomodar quem escreve.
            }
        }
    }
}

// MARK: - Consult sheet

/// Sheet com busca no índice on-device (BookChunk + RAGService) e nos
/// exemplos literários curados (LiteraryExamplesService). Inicializa o
/// campo com `seedQuery` (último parágrafo ou título da nota).
struct ConsultBooksSheet: View {
    let seedQuery: String
    @Environment(\.dismiss) private var dismiss
    @Query private var allChunks: [BookChunk]

    @State private var query: String = ""
    @State private var results: [RetrievedChunk] = []
    @State private var literaryHits: [LiteraryExample] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(Spacing.md)

                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        if !literaryHits.isEmpty {
                            literarySection
                        }

                        if !results.isEmpty {
                            bookSection
                        }

                        if results.isEmpty && literaryHits.isEmpty {
                            if allChunks.isEmpty {
                                emptyLibrary
                            } else {
                                placeholder
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.lg)
                }
            }
            .paperBackground()
            .navigationTitle("Consultar acervo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(Color.accentInk)
                }
            }
            .onAppear {
                if query.isEmpty {
                    query = seedQuery
                }
                runSearch()
            }
        }
    }

    // MARK: - Sections

    private var literarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Exemplos da literatura", systemImage: "books.vertical.fill")
            ForEach(literaryHits) { ex in
                literaryCard(ex)
            }
        }
        .padding(.top, Spacing.xs)
    }

    private var bookSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Dicas do seu acervo", systemImage: "text.book.closed")
            ForEach(Array(results.enumerated()), id: \.offset) { _, hit in
                bookCard(hit)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(title.uppercased())
                .font(.captionMono)
        }
        .foregroundStyle(Color.inkTertiary)
        .padding(.leading, Spacing.xs)
    }

    private func literaryCard(_ ex: LiteraryExample) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ex.principlePT)
                .font(.captionSerif)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            Text(ex.passage)
                .font(.bodySerif)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(6)
                .padding(.top, 2)
            HStack(spacing: 4) {
                Text(ex.author).font(.captionSerifSmall).italic()
                Text("·")
                Text(ex.source)
                Text("·")
                Text(String(ex.year))
            }
            .font(.captionSerifSmall)
            .foregroundStyle(Color.accentInk)
            .padding(.top, 4)
        }
        .paperCard()
    }

    private func bookCard(_ hit: RetrievedChunk) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hit.bookTitle)
                    .font(.captionMono)
                    .foregroundStyle(Color.accentInk)
                Spacer()
                Text(String(format: "%.0f%%", hit.score * 100))
                    .font(.captionMono)
                    .foregroundStyle(Color.inkTertiary)
            }
            Text(hit.content)
                .font(.bodySerif)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(8)
        }
        .paperCard()
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSecondary)
            TextField("Cole um trecho ou descreva o tema", text: $query, axis: .vertical)
                .font(.bodySerif)
                .lineLimit(1...3)
                .tint(Color.accentInk)
                .submitLabel(.search)
                .onSubmit { runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                .fill(Color.paperRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                .strokeBorder(Color.inkDivider, lineWidth: 0.5)
        )
    }

    private var emptyLibrary: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Sem acervo importado")
                .font(.title3Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Importe PDFs na aba Livros\npra consultar dicas dos seus livros.")
                .font(.captionSerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Digite um tema ou cole um trecho.")
                .font(.captionSerif)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            results = []
            literaryHits = []
            return
        }
        results = RAGService.retrieve(query: q, from: allChunks, topK: 6)
        literaryHits = LiteraryExamplesService.search(query: q, topK: 2)
    }
}
