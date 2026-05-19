import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    /// Persisted as raw string so SwiftData doesn't choke on enum migrations.
    var tagRaw: String

    init(title: String = "", body: String = "", tag: NoteTag = .outro) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tagRaw = tag.rawValue
    }

    var tag: NoteTag {
        get { NoteTag(rawValue: tagRaw) ?? .outro }
        set { tagRaw = newValue.rawValue }
    }

    /// Aproximação simples — boa o suficiente pra contadores na UI.
    var wordCount: Int {
        body
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    /// Resumo curto pra usar como subtítulo na lista quando não há título.
    var snippet: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Nota vazia" }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        if firstLine.count <= 80 { return firstLine }
        return String(firstLine.prefix(80)) + "…"
    }

    /// Título efetivo para listas: usa `title` se preenchido, senão o primeiro pedaço do corpo.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.isEmpty { return "Sem título" }
        return String(trimmedBody.prefix(40))
    }
}

enum NoteTag: String, CaseIterable, Identifiable {
    case cena       = "Cena"
    case personagem = "Personagem"
    case ideia      = "Ideia"
    case diario     = "Diário"
    case outro      = "Outro"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .cena:       return "theatermasks"
        case .personagem: return "person.crop.circle"
        case .ideia:      return "lightbulb"
        case .diario:     return "book.closed"
        case .outro:      return "doc.text"
        }
    }
}
