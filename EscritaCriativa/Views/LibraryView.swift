import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Query(sort: \Book.addedDate, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var context
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            content
                .paperBackground()
                .navigationTitle("Livros")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(Color.paperPrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPicker = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentInk)
                                .font(.title3)
                        }
                    }
                }
                .sheet(isPresented: $showPicker) {
                    DocumentPicker { url in
                        Task { await importBook(from: url) }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if books.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    metaHeader
                    ForEach(books) { book in
                        BookCard(book: book)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(book)
                                } label: {
                                    Label("Remover livro", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    private var metaHeader: some View {
        HStack {
            Text("\(books.count) \(books.count == 1 ? "livro" : "livros")")
            Text("·")
            Text("\(totalChunks) trechos")
        }
        .font(.captionSerif)
        .foregroundStyle(Color.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Estante vazia")
                .font(.title2Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Importe PDFs de livros sobre o ofício\npara que a IA cite-os ao te aconselhar.")
                .font(.bodySerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
            Button {
                showPicker = true
            } label: {
                Label("Adicionar primeiro livro", systemImage: "plus")
            }
            .buttonStyle(InkButtonStyle())
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalChunks: Int {
        books.reduce(0) { $0 + $1.chunkCount }
    }

    private func delete(_ book: Book) {
        let bookId = book.id
        let descriptor = FetchDescriptor<BookChunk>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        if let chunks = try? context.fetch(descriptor) {
            chunks.forEach { context.delete($0) }
        }
        context.delete(book)
        try? context.save()
    }

    private func importBook(from url: URL) async {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        let title = url.deletingPathExtension().lastPathComponent
        let book = Book(title: title, filename: url.lastPathComponent)
        book.isProcessing = true
        context.insert(book)
        try? context.save()

        let chunkData = await PDFIngestionService.shared.extractChunks(
            url: url,
            bookId: book.id,
            bookTitle: book.title
        )

        for data in chunkData {
            let chunk = BookChunk(
                bookId: data.bookId,
                bookTitle: data.bookTitle,
                content: data.content,
                pageNumber: data.pageNumber
            )
            context.insert(chunk)
        }
        book.chunkCount = chunkData.count
        book.isProcessing = false
        try? context.save()
    }
}

// MARK: - Book card

struct BookCard: View {
    let book: Book

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            spine
                .frame(width: 36, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headlineSerif)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)

                if book.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Indexando…")
                            .font(.captionSerif)
                            .foregroundStyle(Color.inkSecondary)
                    }
                } else {
                    HStack(spacing: Spacing.xs) {
                        Text("\(book.chunkCount) trechos")
                            .font(.captionSerif)
                            .foregroundStyle(Color.inkSecondary)
                        Text("·")
                            .foregroundStyle(Color.inkTertiary)
                        Text(book.addedDate.formatted(.relative(presentation: .named)))
                            .font(.captionSerifSmall)
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
            }
            Spacer()
        }
        .paperCard()
    }

    /// Pequena "lombada" decorativa — derivada do hash do título pra dar variação visual.
    private var spine: some View {
        let palette: [Color] = [
            Color.accentInk,
            Color.accentSoft,
            Color.inkPrimary.opacity(0.75),
            Color.inkSecondary,
        ]
        let idx = abs(book.title.hashValue) % palette.count
        let color = palette[idx]
        return ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
            Text(String(book.title.prefix(1)).uppercased())
                .font(.system(.headline, design: .serif).weight(.bold))
                .foregroundStyle(Color.paperPrimary)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 2, x: 1, y: 1)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            urls.forEach { onPick($0) }
        }
    }
}
