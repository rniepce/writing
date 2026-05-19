import SwiftUI

/// Sheet que mostra um (ou mais) trecho literário curado.
/// Usa tipografia serifada bem espaçada — passagens são pra serem LIDAS.
struct LiteraryExampleSheet: View {
    /// Query usada pra rankear (ex: o conteúdo da dica do dia, ou pergunta no Caderno).
    let query: String
    /// Quantos exemplos mostrar.
    let topK: Int

    @Environment(\.dismiss) private var dismiss
    @State private var examples: [LiteraryExample] = []

    init(query: String, topK: Int = 1) {
        self.query = query
        self.topK = topK
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if examples.isEmpty {
                        emptyState
                    } else {
                        ForEach(examples) { ex in
                            ExampleCard(example: ex)
                        }
                        footerNote
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .paperBackground()
            .navigationTitle("Exemplo na ficção")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(Color.accentInk)
                }
            }
            .onAppear {
                examples = LiteraryExamplesService.search(query: query, topK: topK)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.inkTertiary)
            Text("Sem exemplo correspondente")
                .font(.title3Serif)
                .foregroundStyle(Color.inkPrimary)
            Text("Esse tema ainda não tem trecho curado.\nO acervo cresce com o tempo.")
                .font(.captionSerif)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
    }

    private var footerNote: some View {
        Text("Todos os trechos estão em domínio público.")
            .font(.captionSerifSmall)
            .foregroundStyle(Color.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.xs)
    }
}

// MARK: - Card individual

private struct ExampleCard: View {
    let example: LiteraryExample

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Cabeçalho: princípio que o trecho ilustra
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Color.accentInk)
                    .font(.caption)
                    .padding(.top, 2)
                Text(example.principlePT)
                    .font(.captionSerif)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }

            Divider().background(Color.inkDivider)

            // Passagem em destaque
            Image(systemName: "quote.opening")
                .foregroundStyle(Color.accentSoft)
                .font(.title3)
            Text(example.passage)
                .font(.system(.title3, design: .serif).weight(.regular))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // Atribuição
            VStack(alignment: .leading, spacing: 2) {
                Text(example.author)
                    .font(.bodySerifEmphasis)
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 4) {
                    Text(example.source)
                        .italic()
                    Text("·")
                    Text(String(example.year))
                    if let tr = example.translation {
                        Text("·")
                        Text("trad. \(tr)")
                    }
                }
                .font(.captionSerif)
                .foregroundStyle(Color.inkSecondary)
            }

            // Tags
            if !example.tags.isEmpty {
                tagChips
            }
        }
        .paperCard(cornerRadius: Corner.lg, padding: Spacing.lg)
    }

    private var tagChips: some View {
        // FlowLayout simples via wrapping HStack — bom o bastante pra 4-8 tags curtas.
        FlowingTags(tags: example.tags)
    }
}

/// Render simples e wrap-friendly de tags.
private struct FlowingTags: View {
    let tags: [String]

    var body: some View {
        // Usa Layout API do SwiftUI (iOS 16+).
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.captionMono)
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.inkTertiary.opacity(0.45), lineWidth: 0.5)
                    )
            }
        }
    }
}

/// Layout customizado pra fluxo horizontal com wrap automático.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.reduce(0) { partial, row in
            partial + (row.first?.size.height ?? 0) + (partial == 0 ? 0 : spacing)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let rows = arrange(subviews: subviews, in: maxWidth)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.size.width + spacing
            }
            y += (row.first?.size.height ?? 0) + spacing
        }
    }

    private struct Item {
        let view: LayoutSubview
        let size: CGSize
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var x: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !(rows.last?.isEmpty ?? true) {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(Item(view: view, size: size))
            x += size.width + spacing
        }
        return rows
    }
}
