import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var hasKey = false
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    apiCard
                    aboutCard
                    creditCard
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .paperBackground()
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.paperPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { reloadKey() }
            .alert("Chave salva", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Sua chave fica no Keychain do iPhone.")
            }
        }
    }

    // MARK: - Cards

    private var apiCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Chave do DeepSeek", systemImage: "key.fill")

            HStack(spacing: Spacing.xs) {
                Image(systemName: hasKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(hasKey ? Color.green : Color.accentInk)
                Text(hasKey ? "Conectada" : "Sem chave configurada")
                    .font(.captionSerif)
                    .foregroundStyle(Color.inkSecondary)
            }

            SecureField("Cole sua chave aqui", text: $apiKey)
                .font(.bodySerif)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Corner.sm)
                        .fill(Color.paperSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.sm)
                        .strokeBorder(Color.inkDivider, lineWidth: 0.5)
                )

            HStack(spacing: Spacing.xs) {
                Button("Salvar") {
                    KeychainService.save(value: apiKey, forAccount: KeychainService.deepSeekKeyAccount)
                    hasKey = !apiKey.isEmpty
                    showSavedAlert = true
                }
                .buttonStyle(InkButtonStyle())
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if hasKey {
                    Button("Remover") {
                        KeychainService.save(value: "", forAccount: KeychainService.deepSeekKeyAccount)
                        apiKey = ""
                        hasKey = false
                    }
                    .buttonStyle(OutlineInkButtonStyle())
                }
            }

            Text("A chave fica salva no Keychain do iPhone e só é enviada para a DeepSeek.")
                .font(.captionSerifSmall)
                .foregroundStyle(Color.inkTertiary)
                .padding(.top, Spacing.xxs)
        }
        .paperCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Sobre o app", systemImage: "info.circle")
            row("Versão", "1.0")
            row("Modelo", "deepseek-chat")
            row("Busca on-device", "BM25 (Jaccard)")
            row("Target", "iOS 17+")
        }
        .paperCard()
    }

    private var creditCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(Color.accentSoft)
            Text("A escrita é o pensar de novo, com paciência.")
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Color.inkPrimary)
            Text("— anônimo")
                .font(.captionSerif)
                .foregroundStyle(Color.inkSecondary)
                .padding(.top, Spacing.xxs)
        }
        .paperCard()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentInk)
            Text(title)
                .font(.headlineSerif)
                .foregroundStyle(Color.inkPrimary)
        }
    }

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
        .padding(.vertical, 2)
    }

    private func reloadKey() {
        if let key = KeychainService.load(account: KeychainService.deepSeekKeyAccount), !key.isEmpty {
            apiKey = key
            hasKey = true
        } else {
            apiKey = ""
            hasKey = false
        }
    }
}
