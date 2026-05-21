import SwiftUI
import SwiftData

struct CadernoView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var search = ""
    @State private var selectedTag: NoteTag? = nil
    @State private var newNote: Note? = nil  // sheet binding for editor
    @State private var navigateToNew: Bool = false
    @State private var noteToDelete: Note? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                listContent

                createButton
                    .padding(Spacing.lg)
            }
            .paperBackground()
            .navigationTitle("Caderno")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $search, prompt: "Buscar nas notas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !notes.isEmpty {
                        ShareLink(
                            item: allNotesAsMarkdown,
                            subject: Text("Caderno — Escrita Criativa"),
                            preview: SharePreview("Todas as notas")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.accentInk)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    tagFilterMenu
                }
            }
            .alert(
                "Apagar nota?",
                isPresented: Binding(
                    get: { noteToDelete != nil },
                    set: { if !$0 { noteToDelete = nil } }
                ),
                presenting: noteToDelete
            ) { note in
                Button("Apagar", role: .destructive) {
                    delete(note)
                    noteToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    noteToDelete = nil
                }
            } message: { note in
                Text("\"\(note.displayTitle)\" será apagada permanentemente.")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var listContent: some View {
        if filteredNotes.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm, pinnedViews: []) {
                    metaHeader
                    if isFiltering {
                        ForEach(filteredNotes) { note in
                            noteLink(note)
                        }
                    } else {
                        ForEach(NoteDateBucket.allCases) { bucket in
                            let entries = grouped[bucket] ?? []
                            if !entries.isEmpty {
                                Text(bucket.title.uppercased())
                                    .font(.captionMono)
                                    .foregroundStyle(Color.inkTertiary)
                                    .padding(.horizontal, Spacing.xs)
                                    .padding(.top, Spacing.sm)
                                ForEach(entries) { note in
                                    noteLink(note)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .padding(.bottom, 96)  // espaço pro FAB
            }
        }
    }

    private func noteLink(_ note: Note) -> some View {
        NavigationLink {
            NoteEditorView(note: note)
        } label: {
            NoteRow(note: note)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: noteAsMarkdown(note), subject: Text(note.displayTitle)) {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                noteToDelete = note
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
    }

    private func noteAsMarkdown(_ note: Note) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? note.body : "# \(title)\n\n\(note.body)"
    }

    private var isFiltering: Bool {
        !search.isEmpty || selectedTag != nil
    }

    private var metaHeader: some View {
        HStack {
            Text("\(filteredNotes.count) \(filteredNotes.count == 1 ? "nota" : "notas")")
            Text("·")
            Text("\(totalWords) palavras")
        }
        .font(.captionSerif)
        .foregroundStyle(Color.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "book.pages")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Caderno em branco")
                .font(.title2Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Comece uma cena, esboce um personagem,\nou anote uma ideia antes que ela escape.")
                .font(.bodySerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
            Button {
                createNewNote()
            } label: {
                Label("Começar a escrever", systemImage: "square.and.pencil")
            }
            .buttonStyle(InkButtonStyle())
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tagFilterMenu: some View {
        Menu {
            Button {
                selectedTag = nil
            } label: {
                Label("Todas as tags", systemImage: selectedTag == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(NoteTag.allCases) { tag in
                Button {
                    selectedTag = (selectedTag == tag) ? nil : tag
                } label: {
                    Label(
                        tag.rawValue,
                        systemImage: selectedTag == tag ? "checkmark" : tag.symbol
                    )
                }
            }
        } label: {
            Image(systemName: selectedTag == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.accentInk)
        }
    }

    private var createButton: some View {
        Button {
            createNewNote()
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.paperPrimary)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(Color.accentInk)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Nova nota")
    }

    // MARK: - Derived data

    private var filteredNotes: [Note] {
        let base = notes.filter { note in
            (selectedTag == nil || note.tag == selectedTag) &&
            (search.isEmpty || matches(note, query: search))
        }
        // Quando o usuário busca, ordena por relevância (score de overlap).
        // Sem busca, mantém ordem cronológica natural (já vem do @Query).
        if search.isEmpty { return base }
        return base.sorted { lhs, rhs in
            relevance(of: lhs, query: search) > relevance(of: rhs, query: search)
        }
    }

    /// Notas agrupadas em buckets de tempo (Hoje / Ontem / Esta semana / Mais antigas).
    private var grouped: [NoteDateBucket: [Note]] {
        Dictionary(grouping: filteredNotes, by: { NoteDateBucket.bucket(for: $0.updatedAt) })
    }

    private var totalWords: Int {
        filteredNotes.reduce(0) { $0 + $1.wordCount }
    }

    /// Match: substring no título OU substring no corpo OU overlap de palavras-chave.
    /// O overlap dá +relevância pra acentos diferentes e termos relacionados.
    private func matches(_ note: Note, query: String) -> Bool {
        let q = query
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .lowercased()
        let title = note.title
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .lowercased()
        let body = note.body
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .lowercased()
        if title.contains(q) || body.contains(q) { return true }
        // fallback: pelo menos uma palavra significativa em comum (>3 chars)
        let queryWords = Set(q.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count > 3 })
        if queryWords.isEmpty { return false }
        let bodyWords = Set(body.split(whereSeparator: { !$0.isLetter }).map(String.init))
        return !queryWords.isDisjoint(with: bodyWords)
    }

    private func relevance(of note: Note, query: String) -> Double {
        let q = query.lowercased()
        var score = 0.0
        if note.title.lowercased().contains(q) { score += 3 }
        if note.body.lowercased().contains(q) { score += 2 }
        let qw = Set(q.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count > 3 })
        let bw = Set(note.body.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        score += Double(qw.intersection(bw).count)
        return score
    }

    /// Export de todas as notas como um único documento markdown. Útil
    /// pra dump completo sem mexer com .zip (que iOS não tem nativo).
    private var allNotesAsMarkdown: String {
        let header = """
        # Caderno

        Exportado em \(Date().formatted(.dateTime.day().month(.wide).year()))
        Total: \(notes.count) \(notes.count == 1 ? "nota" : "notas") · \(notes.reduce(0) { $0 + $1.wordCount }) palavras

        ---
        """

        let body = notes.map { note -> String in
            let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let titleLine = title.isEmpty ? "## \(note.displayTitle)" : "## \(title)"
            let meta = "*\(note.tag.rawValue) · \(note.wordCount) palavras · \(note.updatedAt.formatted(.dateTime.day().month().year()))*"
            return "\(titleLine)\n\n\(meta)\n\n\(note.body)\n"
        }.joined(separator: "\n---\n\n")

        return header + "\n\n" + body
    }

    // MARK: - Actions

    private func createNewNote() {
        // Cria + navega imediatamente pro editor via NavigationLink programático.
        let note = Note()
        context.insert(note)
        try? context.save()
        newNote = note
        navigateToNew = true
    }

    private func delete(_ note: Note) {
        context.delete(note)
        try? context.save()
    }
}

// MARK: - Row

struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: note.tag.symbol)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentSoft)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle)
                    .font(.headlineSerif)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Text(note.snippet)
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)

                HStack(spacing: Spacing.xs) {
                    Text(note.tag.rawValue.uppercased())
                        .font(.captionMono)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.inkTertiary.opacity(0.6), lineWidth: 0.5)
                        )

                    Text("\(note.wordCount) palavras")
                        .font(.captionSerifSmall)
                        .foregroundStyle(Color.inkTertiary)

                    Spacer()

                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.captionSerifSmall)
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.top, 2)
            }
        }
        .paperCard()
    }
}
