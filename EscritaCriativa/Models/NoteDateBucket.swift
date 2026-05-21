import Foundation

/// Buckets de data pra agrupar as notas no Caderno em seções "Hoje / Ontem /
/// Esta semana / Mais antigas". Não persiste — é puro derivado de `updatedAt`.
enum NoteDateBucket: String, CaseIterable, Identifiable {
    case today, yesterday, thisWeek, older

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:     return "Hoje"
        case .yesterday: return "Ontem"
        case .thisWeek:  return "Esta semana"
        case .older:     return "Mais antigas"
        }
    }

    static func bucket(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> NoteDateBucket {
        let today = calendar.startOfDay(for: now)
        let noteDay = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: noteDay, to: today).day ?? 0
        switch diff {
        case ..<0:   return .today        // futuro (relógio cagado) — bucket vivo
        case 0:      return .today
        case 1:      return .yesterday
        case 2...7:  return .thisWeek
        default:     return .older
        }
    }
}
