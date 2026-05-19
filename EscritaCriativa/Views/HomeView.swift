import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var tips: [Tip]
    @Query private var notes: [Note]
    @State private var randomTip: Tip?
    @State private var heartScale: CGFloat = 1
    @State private var showExampleSheet = false

    private var displayTip: Tip? { randomTip ?? TipsService.todayTip(from: tips) }
    private var isDaily: Bool { randomTip == nil }
    private var stats: WritingStats { WritingStats.from(notes: notes) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let tip = displayTip {
                        dateHeader
                        TipCard(
                            tip: tip,
                            isDaily: isDaily,
                            heartScale: $heartScale,
                            onSeeExample: { showExampleSheet = true }
                        )
                        actions
                        if stats.hasAnyActivity {
                            statsStrip
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .paperBackground()
            .navigationTitle("Hoje")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showExampleSheet) {
                if let tip = displayTip {
                    LiteraryExampleSheet(query: tip.content, topK: 1)
                }
            }
        }
    }

    // MARK: - Subviews

    private var dateHeader: some View {
        VStack(spacing: 2) {
            Text(isDaily
                 ? Date().formatted(.dateTime.weekday(.wide))
                 : "Aleatória")
                .font(.captionMono)
                .foregroundStyle(Color.inkTertiary)
                .textCase(.uppercase)
            Text(Date().formatted(.dateTime.day().month(.wide).year()))
                .font(.display(20, weight: .regular))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                drawRandomTip()
            } label: {
                Label("Sortear outra dica", systemImage: "shuffle")
            }
            .buttonStyle(OutlineInkButtonStyle())
            .disabled(tips.count <= 1)

            if randomTip != nil {
                Button("Voltar à dica do dia") { randomTip = nil }
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.top, Spacing.xs)
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(stats.wordsThisWeek)", label: "palavras\nesta semana")
            Divider().background(Color.inkDivider)
            statColumn(
                value: "\(stats.currentStreak)",
                label: stats.currentStreak == 1 ? "dia\nde escrita" : "dias\nseguidos"
            )
            Divider().background(Color.inkDivider)
            statColumn(value: "\(stats.totalNotes)", label: stats.totalNotes == 1 ? "nota\nno caderno" : "notas\nno caderno")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                .fill(Color.paperRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md, style: .continuous)
                .strokeBorder(Color.inkDivider, lineWidth: 0.5)
        )
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(22, weight: .semibold))
                .foregroundStyle(Color.accentInk)
            Text(label)
                .font(.captionSerifSmall)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Sem dicas")
                .font(.title2Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Edite `tips_iniciais.json` e recompile\npara semear seu repertório.")
                .font(.captionSerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func drawRandomTip() {
        randomTip = tips.filter { $0.id != displayTip?.id }.randomElement() ?? tips.randomElement()
    }
}

// MARK: - Card

struct TipCard: View {
    @Bindable var tip: Tip
    let isDaily: Bool
    @Binding var heartScale: CGFloat
    var onSeeExample: () -> Void = {}

    /// Pré-calcula se há um exemplo curado relevante pra essa dica.
    /// Evita mostrar um botão que abriria um sheet vazio.
    private var hasExample: Bool {
        LiteraryExamplesService.best(for: tip.content) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(Color.accentSoft)

            Text(tip.content)
                .font(.system(.title3, design: .serif).weight(.regular))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.inkDivider)

            HStack(alignment: .center) {
                Text(tip.source)
                    .font(.captionSerif)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                        tip.isFavorite.toggle()
                        heartScale = tip.isFavorite ? 1.25 : 0.85
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) {
                        heartScale = 1
                    }
                } label: {
                    Image(systemName: tip.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(tip.isFavorite ? Color.accentInk : Color.inkSecondary)
                        .scaleEffect(heartScale)
                }
                .buttonStyle(.plain)
            }

            if hasExample {
                Button {
                    onSeeExample()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                            .font(.caption)
                        Text("Ver exemplo na ficção")
                            .font(.calloutSerif)
                    }
                }
                .buttonStyle(OutlineInkButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xxs)
            }
        }
        .paperCard(cornerRadius: Corner.lg, padding: Spacing.lg)
    }
}
