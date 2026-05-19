import SwiftUI
import SwiftData

/// Sheet com todas as dicas favoritadas (Tip.isFavorite == true).
/// Mostrada a partir do botão de coração no toolbar da aba Hoje.
struct FavoriteTipsSheet: View {
    @Query(filter: #Predicate<Tip> { $0.isFavorite }) private var favorites: [Tip]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .paperBackground()
            .navigationTitle("Favoritas")
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                Text("\(favorites.count) \(favorites.count == 1 ? "dica favoritada" : "dicas favoritadas")")
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.xs)

                ForEach(favorites) { tip in
                    FavoriteRow(tip: tip)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "heart")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Sem favoritas ainda")
                .font(.title2Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Toque no coração de uma dica\npra guardá-la aqui.")
                .font(.captionSerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

private struct FavoriteRow: View {
    @Bindable var tip: Tip

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(tip.content)
                .font(.bodySerif)
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            HStack {
                Text(tip.source)
                    .font(.captionSerif)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        tip.isFavorite.toggle()
                    }
                } label: {
                    Image(systemName: tip.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(tip.isFavorite ? Color.accentInk : Color.inkSecondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
        }
        .paperCard()
    }
}
