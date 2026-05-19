import Foundation

/// Estatísticas derivadas das notas do Caderno. Não persiste — é calculado
/// na hora a partir do array de Note.
struct WritingStats {
    let totalNotes: Int
    let totalWords: Int
    let wordsThisWeek: Int
    /// Dias seguidos terminando em hoje com ao menos uma nota tocada.
    /// Se o usuário não escreveu hoje, o streak é 0 (zero, não "ontem foi 5").
    let currentStreak: Int

    var hasAnyActivity: Bool { totalNotes > 0 }

    static func from(notes: [Note], now: Date = Date(), calendar: Calendar = .current) -> WritingStats {
        let total = notes.count
        let words = notes.reduce(0) { $0 + $1.wordCount }

        // Semana = últimos 7 dias incluindo hoje (rolling window).
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let weekWords = notes
            .filter { $0.updatedAt >= weekStart }
            .reduce(0) { $0 + $1.wordCount }

        // Streak = quantos dias consecutivos a partir de hoje (inclusive)
        // têm pelo menos uma nota com updatedAt naquele dia.
        let touchedDays: Set<Date> = Set(notes.map { calendar.startOfDay(for: $0.updatedAt) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while touchedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return WritingStats(
            totalNotes: total,
            totalWords: words,
            wordsThisWeek: weekWords,
            currentStreak: streak
        )
    }
}
