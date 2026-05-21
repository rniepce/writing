import SwiftUI

/// Apresentação curta na primeira abertura. 4 cards paginados.
/// Estado persistido em UserDefaults via `@AppStorage("didShowOnboarding")`.
struct OnboardingView: View {
    @AppStorage("didShowOnboarding") private var didShowOnboarding: Bool = false
    @State private var page: Int = 0
    @Environment(AppState.self) private var appState

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "book.pages",
            title: "Um caderno que pensa junto",
            body: "Escreva cenas, esboce personagens, anote ideias antes que escapem. Cada nota guarda contagem de palavras e auto-save."
        ),
        OnboardingPage(
            symbol: "sparkles",
            title: "Uma dica de craft por dia",
            body: "Uma técnica de escrita por dia, curada por você. Cada dica vem com um trecho da literatura (Joyce, Chekhov, Tolstoy…) que a ilustra."
        ),
        OnboardingPage(
            symbol: "bubble.left.and.bubble.right",
            title: "Pergunte ao DeepSeek",
            body: "Conecte sua chave em Ajustes e converse sobre o que está te travando. Do editor, você pode anexar um trecho do caderno e pedir feedback direto."
        ),
        OnboardingPage(
            symbol: "books.vertical",
            title: "Seu acervo, citável",
            body: "Importe PDFs de livros sobre o ofício. O app indexa on-device e cita trechos seus quando você perguntar — no chat ou na nota."
        ),
    ]

    var body: some View {
        ZStack {
            Color.paperPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        OnboardingPageView(page: p)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                actionBar
            }
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack {
            Button("Pular") {
                finish()
            }
            .font(.calloutSerif)
            .foregroundStyle(Color.inkSecondary)

            Spacer()

            Button {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page += 1
                    }
                } else {
                    finish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Próximo" : "Começar a escrever")
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .padding(.top, Spacing.sm)
    }

    private func finish() {
        didShowOnboarding = true
        appState.selectedTab = .caderno
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(Color.accentInk)
                .padding(.bottom, Spacing.sm)

            Text(page.title)
                .font(.display(28, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Text(page.body)
                .font(.bodySerif)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Spacing.xl)

            Spacer()
            Spacer()  // empurra conteúdo pra cima
        }
    }
}
