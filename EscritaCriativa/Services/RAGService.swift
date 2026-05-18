import Foundation

struct RetrievedChunk {
    let content: String
    let bookTitle: String
    let score: Double
}

enum RAGService {
    // Jaccard similarity sobre tokens — BM25 simplificado sem necessidade de embeddings
    static func retrieve(query: String, from chunks: [BookChunk], topK: Int = 5) -> [RetrievedChunk] {
        let queryTokens = Set(tokenize(query))
        guard !queryTokens.isEmpty else { return [] }

        let scored: [(BookChunk, Double)] = chunks.compactMap { chunk in
            let chunkTokens = Set(chunk.tokens)
            let intersection = queryTokens.intersection(chunkTokens)
            guard !intersection.isEmpty else { return nil }
            let union = queryTokens.union(chunkTokens)
            let score = Double(intersection.count) / Double(union.count)
            return (chunk, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { RetrievedChunk(content: $0.0.content, bookTitle: $0.0.bookTitle, score: $0.1) }
    }

    static func buildContext(from chunks: [RetrievedChunk]) -> String {
        chunks.enumerated().map { i, chunk in
            "[\(i + 1)] \(chunk.bookTitle):\n\(chunk.content)"
        }.joined(separator: "\n\n---\n\n")
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
    }
}
