import PDFKit
import Foundation

actor PDFIngestionService {
    static let shared = PDFIngestionService()
    private init() {}

    private let chunkSize = 500
    private let overlap = 50

    struct ChunkData {
        let bookId: UUID
        let bookTitle: String
        let content: String
        let pageNumber: Int
    }

    func extractChunks(url: URL, bookId: UUID, bookTitle: String) -> [ChunkData] {
        guard let pdf = PDFDocument(url: url) else { return [] }

        var chunks: [ChunkData] = []

        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i),
                  let text = page.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }

            let words = text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            var start = 0
            while start < words.count {
                let end = min(start + chunkSize, words.count)
                let content = words[start..<end].joined(separator: " ")
                chunks.append(ChunkData(
                    bookId: bookId,
                    bookTitle: bookTitle,
                    content: content,
                    pageNumber: i + 1
                ))
                if end == words.count { break }
                start += chunkSize - overlap
            }
        }

        return chunks
    }
}
