import Foundation
import SwiftData

@Model
final class BookChunk {
    var id: UUID
    var bookId: UUID
    var bookTitle: String
    var content: String
    var tokens: [String]
    var pageNumber: Int

    init(bookId: UUID, bookTitle: String, content: String, pageNumber: Int) {
        self.id = UUID()
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.content = content
        self.pageNumber = pageNumber
        self.tokens = content
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
    }
}
