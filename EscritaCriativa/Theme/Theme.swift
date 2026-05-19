import SwiftUI

// MARK: - Color tokens (papel + tinta)
// Light = página de caderno creme. Dark = couro envelhecido.
// Cores são definidas inline (sem Assets.xcassets) para minimizar pegada
// no projeto e manter o tema rastreável num único arquivo.

extension Color {
    // Backgrounds
    static let paperPrimary = Color(
        light: Color(red: 0.961, green: 0.929, blue: 0.878),   // #F5EDE0
        dark:  Color(red: 0.102, green: 0.086, blue: 0.071)    // #1A1612
    )
    static let paperSecondary = Color(
        light: Color(red: 0.984, green: 0.965, blue: 0.925),   // #FBF6EC
        dark:  Color(red: 0.133, green: 0.110, blue: 0.086)    // #221C16
    )
    static let paperRaised = Color(
        light: Color.white,
        dark:  Color(red: 0.16, green: 0.135, blue: 0.105)
    )

    // Foregrounds
    static let inkPrimary = Color(
        light: Color(red: 0.106, green: 0.086, blue: 0.067),   // #1B1611
        dark:  Color(red: 0.937, green: 0.898, blue: 0.820)    // #EFE5D1
    )
    static let inkSecondary = Color(
        light: Color(red: 0.427, green: 0.373, blue: 0.310),   // #6D5F4F
        dark:  Color(red: 0.690, green: 0.635, blue: 0.545)    // #B0A28B
    )
    static let inkTertiary = Color(
        light: Color(red: 0.608, green: 0.545, blue: 0.467),   // #9B8B77
        dark:  Color(red: 0.478, green: 0.431, blue: 0.357)    // #7A6E5B
    )

    // Accent (sepia/amber)
    static let accentInk = Color(
        light: Color(red: 0.549, green: 0.247, blue: 0.169),   // #8C3F2B oxblood
        dark:  Color(red: 0.851, green: 0.596, blue: 0.361)    // #D9985C amber
    )
    static let accentSoft = Color(
        light: Color(red: 0.722, green: 0.604, blue: 0.373),   // #B89A5F
        dark:  Color(red: 0.612, green: 0.498, blue: 0.302)    // #9C7F4D
    )

    // Divider
    static var inkDivider: Color { Color.inkPrimary.opacity(0.12) }
}

// Convenience to compose dynamic colors without Assets.xcassets.
private extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Typography
// Tudo serifado, exceto valores numéricos onde o monospace ajuda na leitura.

extension Font {
    static func display(_ size: CGFloat = 32, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static var titleSerif: Font          { .system(.title, design: .serif).weight(.semibold) }
    static var title2Serif: Font         { .system(.title2, design: .serif).weight(.semibold) }
    static var title3Serif: Font         { .system(.title3, design: .serif).weight(.medium) }
    static var headlineSerif: Font       { .system(.headline, design: .serif).weight(.semibold) }
    static var bodySerif: Font           { .system(.body, design: .serif) }
    static var bodySerifEmphasis: Font   { .system(.body, design: .serif).weight(.medium) }
    static var calloutSerif: Font        { .system(.callout, design: .serif) }
    static var captionSerif: Font        { .system(.footnote, design: .serif) }
    static var captionSerifSmall: Font   { .system(.caption, design: .serif) }

    static var captionMono: Font         { .system(.caption2, design: .monospaced).weight(.medium) }
}

// MARK: - Spacing & corners

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Corner {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
}

// MARK: - Reusable view modifiers

/// Card estilo página de caderno: fundo claro, borda fina cor tinta, sombra suave.
struct PaperCardStyle: ViewModifier {
    var cornerRadius: CGFloat = Corner.md
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.paperRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.inkDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func paperCard(cornerRadius: CGFloat = Corner.md, padding: CGFloat = Spacing.md) -> some View {
        modifier(PaperCardStyle(cornerRadius: cornerRadius, padding: padding))
    }

    /// Aplica o background creme do app — usar no nível mais alto de cada tab.
    func paperBackground() -> some View {
        self.background(Color.paperPrimary.ignoresSafeArea())
    }
}

/// Botão accent inspirado em selo/carimbo.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodySerifEmphasis)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .foregroundStyle(Color.paperPrimary)
            .background(
                RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                    .fill(Color.accentInk)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Botão secundário discreto (outline).
struct OutlineInkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.calloutSerif)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(Color.inkPrimary)
            .background(
                RoundedRectangle(cornerRadius: Corner.sm, style: .continuous)
                    .strokeBorder(Color.inkPrimary.opacity(0.4), lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
