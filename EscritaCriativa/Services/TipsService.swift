import Foundation
import SwiftData

enum TipsService {
    private struct TipDTO: Decodable {
        let id: String
        let content: String
        let source: String
    }

    static func todayTip(from tips: [Tip]) -> Tip? {
        guard !tips.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return tips[(dayOfYear - 1) % tips.count]
    }

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Tip>()
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "tips_iniciais", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([TipDTO].self, from: data)
        else { return }

        for dto in dtos {
            context.insert(Tip(id: dto.id, content: dto.content, source: dto.source))
        }
        try? context.save()
    }
}
