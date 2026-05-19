import Foundation

/// Trecho canônico em domínio público (ou fair use curto), carregado do
/// bundle. NÃO é @Model — é seed estática, não persiste no SwiftData.
struct LiteraryExample: Identifiable, Codable, Hashable {
    let id: String
    let passage: String
    let source: String
    let author: String
    let year: Int
    let translation: String?
    /// Descrição em português do princípio que o trecho ilustra.
    /// É a chave primária da busca por overlap.
    let principlePT: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, passage, source, author, year, translation, tags
        case principlePT = "principle_pt"
    }

    /// Citação compacta para legenda: "Tolstoy, Anna Karenina (1878)".
    var attribution: String {
        "\(author), \(source) (\(year))"
    }
}
