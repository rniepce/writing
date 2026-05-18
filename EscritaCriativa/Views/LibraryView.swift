import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Query private var books: [Book]
    @Environment(\.modelContext) private var context
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { book in
                    BookRow(book: book)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Biblioteca")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Nenhum livro",
                        systemImage: "book.closed",
                        description: Text("Toque em + para importar PDFs de livros sobre craft de escrita.")
                    )
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    Task { await importBook(from: url) }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            // remove chunks pertencentes ao livro
            let bookId = book.id
            let descriptor = FetchDescriptor<BookChunk>(
                predicate: #Predicate { $0.bookId == bookId }
            )
            if let chunks = try? context.fetch(descriptor) {
                chunks.forEach { context.delete($0) }
            }
            context.delete(book)
        }
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

struct BookRow: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.headline)
            if book.isProcessing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Processando...").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("\(book.chunkCount) trechos indexados")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
