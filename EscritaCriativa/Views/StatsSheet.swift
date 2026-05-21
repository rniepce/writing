import SwiftUI
import SwiftData
import Charts

/// Sheet expandido de estatísticas — chart de 30 dias + resumo.
/// Aberto ao tocar na tira de stats em HomeView.
struct StatsSheet: View {
    @Query private var notes: [Note]
    @Environment(\.dismiss) private var dismiss

    private var stats: WritingStats { WritingStats.from(notes: notes) }
    private var dailySeries: [DailyWordCount] { computeDaily(days: 30) }
    private var bestDay: DailyWordCount? { dailySeries.max(by: { $0.words < $1.words }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    chartCard
                    summaryCard
                    if !notes.isEmpty {
                        recentCard
                    }
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .paperBackground()
            .navigationTitle("Sua escrita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(Color.accentInk)
                }
            }
        }
    }

    // MARK: - Cards

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PALAVRAS POR DIA — ÚLTIMOS 30 DIAS")
                .font(.captionMono)
                .foregroundStyle(Color.inkTertiary)

            Chart(dailySeries) { item in
                BarMark(
                    x: .value("Dia", item.date, unit: .day),
                    y: .value("Palavras", item.words)
                )
                .foregroundStyle(Color.accentInk)
                .cornerRadius(2)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.captionMono)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.captionMono)
                }
            }
        }
        .paperCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("RESUMO")
                .font(.captionMono)
                .foregroundStyle(Color.inkTertiary)

            row("Total de palavras", "\(stats.totalWords)")
            row("Notas no caderno", "\(stats.totalNotes)")
            row("Palavras esta semana", "\(stats.wordsThisWeek)")
            row("Dias seguidos", "\(stats.currentStreak)")
            if let best = bestDay, best.words > 0 {
                row("Melhor dia",
                    "\(best.words) palavras · \(best.date.formatted(.dateTime.day().month(.wide)))")
            }
        }
        .paperCard()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ÚLTIMA NOTA")
                .font(.captionMono)
                .foregroundStyle(Color.inkTertiary)
            if let last = notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
                Text(last.displayTitle)
                    .font(.headlineSerif)
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 6) {
                    Text(last.tag.rawValue.uppercased())
                        .font(.captionMono)
                        .foregroundStyle(Color.accentInk)
                    Text("·")
                    Text("\(last.wordCount) palavras")
                    Text("·")
                    Text(last.updatedAt.formatted(.relative(presentation: .named)))
                }
                .font(.captionSerif)
                .foregroundStyle(Color.inkSecondary)
            }
        }
        .paperCard()
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodySerif)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value)
                .font(.captionMono)
                .foregroundStyle(Color.inkPrimary)
        }
    }

    /// Agrega `wordCount` por dia nos últimos `days` dias.
    private func computeDaily(days: Int) -> [DailyWordCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var buckets: [Date: Int] = [:]
        for offset in 0..<days {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                buckets[day] = 0
            }
        }
        for note in notes {
            let day = cal.startOfDay(for: note.updatedAt)
            if buckets[day] != nil {
                buckets[day, default: 0] += note.wordCount
            }
        }
        return buckets
            .sorted { $0.key < $1.key }
            .map { DailyWordCount(date: $0.key, words: $0.value) }
    }
}

struct DailyWordCount: Identifiable {
    let date: Date
    let words: Int
    var id: Date { date }
}
