import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var tips: [Tip]
    @State private var randomTip: Tip?

    private var displayTip: Tip? { randomTip ?? TipsService.todayTip(from: tips) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let tip = displayTip {
                        TipCard(tip: tip, isDaily: randomTip == nil)
                    } else {
                        ContentUnavailableView(
                            "Sem dicas",
                            systemImage: "text.badge.plus",
                            description: Text("Edite tips_iniciais.json e recompile para adicionar suas dicas.")
                        )
                    }

                    Button("Dica aleatória") {
                        randomTip = tips.filter { $0.id != displayTip?.id }.randomElement() ?? tips.randomElement()
                    }
                    .buttonStyle(.bordered)
                    .disabled(tips.count <= 1)

                    if randomTip != nil {
                        Button("Voltar à dica do dia") { randomTip = nil }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Dica do Dia")
        }
    }
}

struct TipCard: View {
    @Bindable var tip: Tip
    let isDaily: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isDaily {
                Label(Date().formatted(date: .long, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(tip.content)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(tip.source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    tip.isFavorite.toggle()
                } label: {
                    Image(systemName: tip.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(tip.isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
