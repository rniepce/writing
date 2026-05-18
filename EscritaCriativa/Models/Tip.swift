import Foundation
import SwiftData

@Model
final class Tip {
    var id: String
    var content: String
    var source: String
    var isFavorite: Bool

    init(id: String, content: String, source: String = "minha anotação") {
        self.id = id
        self.content = content
        self.source = source
        self.isFavorite = false
    }
}
