import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var filename: String
    var addedDate: Date
    var chunkCount: Int
    var isProcessing: Bool

    init(title: String, filename: String) {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.addedDate = Date()
        self.chunkCount = 0
        self.isProcessing = false
    }
}
