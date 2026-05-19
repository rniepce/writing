import Foundation

/// Carrega trechos do bundle e expõe busca semântica simples baseada
/// em overlap de tokens entre a query e (principle_pt + tags).
/// O corpus é pequeno (~25 itens), então força bruta linear é mais que suficiente.
enum LiteraryExamplesService {

    // MARK: - Carregamento
    static let all: [LiteraryExample] = {
        guard let url = Bundle.main.url(forResource: "literary_examples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([LiteraryExample].self, from: data)
        else {
            assertionFailure("literary_examples.json não encontrado ou inválido no bundle")
            return []
        }
        return parsed
    }()

    // MARK: - Busca

    /// Retorna os top-K exemplos cujos `principlePT` + `tags` mais se sobrepõem
    /// aos tokens da query. Empate é desfeito por data (mais antigos primeiro,
    /// só pra estabilidade — não tem ranking literário envolvido).
    static func search(query: String, topK: Int = 2, excluding: Set<String> = []) -> [LiteraryExample] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        let scored: [(LiteraryExample, Double)] = all.compactMap { ex in
            if excluding.contains(ex.id) { return nil }
            let exTokens = tokenize(ex.principlePT) + ex.tags.flatMap(tokenize)
            let exSet = Set(exTokens)
            let intersection = queryTokens.intersection(exSet)
            guard !intersection.isEmpty else { return nil }
            // Score = Jaccard ponderado por raiz do tamanho da interseção.
            // (Trechos com mais tokens batendo ganham um boost leve.)
            let union = queryTokens.union(exSet)
            let jaccard = Double(intersection.count) / Double(union.count)
            let boosted = jaccard * sqrt(Double(intersection.count))
            return (ex, boosted)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.year < rhs.0.year
            }
            .prefix(topK)
            .map(\.0)
    }

    /// Conveniência: melhor match único.
    static func best(for query: String) -> LiteraryExample? {
        search(query: query, topK: 1).first
    }

    // MARK: - Helpers

    /// Tokens minúsculos, comprimento >= 3, sem pontuação. Inclui o radical de
    /// algumas palavras-chave PT que aparecem nas tips (ex: "frases" → "frase").
    private static func tokenize(_ text: String) -> Set<String> {
        let lowered = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
        let scalars = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        let cleaned = String(scalars)
        let words = cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count >= 3 }
            .map(stem)
        return Set(words)
    }

    /// Stemmer ingênuo PT/EN — remove sufixos de plural e gênero comuns.
    /// Não é Porter, mas resolve "frases" ↔ "frase", "diálogos" ↔ "diálogo" etc.
    private static func stem(_ word: String) -> String {
        var w = word
        for suffix in ["icas", "icos", "mente", "mentes", "oes", "aes", "ais", "eis", "iis", "ois", "uis"] {
            if w.count > suffix.count + 2 && w.hasSuffix(suffix) {
                w = String(w.dropLast(suffix.count))
                break
            }
        }
        for suffix in ["es", "as", "os", "is", "us"] {
            if w.count > suffix.count + 2 && w.hasSuffix(suffix) {
                w = String(w.dropLast(suffix.count))
                break
            }
        }
        if w.count > 3 && w.hasSuffix("s") { w = String(w.dropLast()) }
        return w
    }
}
