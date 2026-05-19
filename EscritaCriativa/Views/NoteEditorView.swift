import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @FocusState private var bodyFocused: Bool
    @State private var showConsultSheet = false
    @State private var showTagPicker = false

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
                    Section("Tag") {
                        ForEach(NoteTag.allCases) { tag in
                            Button {
                                note.tag = tag
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
                        context.delete(note)
                        try? context.save()
                        dismiss()
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
        .toolbarBackground(Color.paperPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: note.title) { _, _ in touch() }
        .onChange(of: note.body)  { _, _ in touch() }
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
                    Text("Escreva...")
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
                Label("Consultar livros", systemImage: "books.vertical")
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
}

// MARK: - Consult sheet

/// Sheet com busca no índice on-device (BookChunk + RAGService).
/// Inicializa o campo com `seedQuery` (último parágrafo ou título da nota).
struct ConsultBooksSheet: View {
    let seedQuery: String
    @Environment(\.dismiss) private var dismiss
    @Query private var allChunks: [BookChunk]

    @State private var query: String = ""
    @State private var results: [RetrievedChunk] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(Spacing.md)

                if allChunks.isEmpty {
                    emptyLibrary
                } else if results.isEmpty {
                    placeholder
                } else {
                    resultList
                }
            }
            .paperBackground()
            .navigationTitle("Consultar livros")
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

    private var searchBar: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSecondary)
            TextField("Sobre o que você quer dica?", text: $query, axis: .vertical)
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
            Text("Biblioteca vazia")
                .font(.title3Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Importe PDFs na aba Biblioteca\npara consultar dicas dos seus livros.")
                .font(.captionSerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(Array(results.enumerated()), id: \.offset) { idx, hit in
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        results = RAGService.retrieve(query: q, from: allChunks, topK: 6)
    }
}
