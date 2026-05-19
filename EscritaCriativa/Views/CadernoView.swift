import SwiftUI
import SwiftData

struct CadernoView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var search = ""
    @State private var selectedTag: NoteTag? = nil
    @State private var newNote: Note? = nil  // sheet binding for editor
    @State private var navigateToNew: Bool = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    tagFilterMenu
                }
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
                LazyVStack(spacing: Spacing.sm) {
                    metaHeader
                    ForEach(filteredNotes) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            NoteRow(note: note)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(note)
                            } label: {
                                Label("Apagar", systemImage: "trash")
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
                Label("Primeira nota", systemImage: "plus")
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
        notes.filter { note in
            (selectedTag == nil || note.tag == selectedTag) &&
            (search.isEmpty || matches(note, query: search))
        }
    }

    private var totalWords: Int {
        filteredNotes.reduce(0) { $0 + $1.wordCount }
    }

    private func matches(_ note: Note, query: String) -> Bool {
        let q = query.lowercased()
        return note.title.lowercased().contains(q) || note.body.lowercased().contains(q)
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
