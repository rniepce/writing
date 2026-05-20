import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var hasKey = false
    @State private var showSavedAlert = false
    @State private var selectedModelID = DeepSeekService.currentModelID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    apiCard
                    modelCard
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
                Text("Você já pode usar o Chat.")
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

            SecureField("sk-…", text: $apiKey)
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
                Button("Salvar chave") {
                    KeychainService.save(value: apiKey, forAccount: KeychainService.deepSeekKeyAccount)
                    hasKey = !apiKey.isEmpty
                    showSavedAlert = true
                }
                .buttonStyle(InkButtonStyle())
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if hasKey {
                    Button("Apagar chave") {
                        KeychainService.save(value: "", forAccount: KeychainService.deepSeekKeyAccount)
                        apiKey = ""
                        hasKey = false
                    }
                    .buttonStyle(OutlineInkButtonStyle())
                }
            }

            Text("Fica no Keychain do iPhone e só sai daqui na chamada pra api.deepseek.com.")
                .font(.captionSerifSmall)
                .foregroundStyle(Color.inkTertiary)
                .padding(.top, Spacing.xxs)
        }
        .paperCard()
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Modelo da IA", systemImage: "sparkles")

            ForEach(DeepSeekService.availableModels) { model in
                Button {
                    selectedModelID = model.id
                    DeepSeekService.currentModelID = model.id
                } label: {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: selectedModelID == model.id
                              ? "largecircle.fill.circle"
                              : "circle")
                            .foregroundStyle(selectedModelID == model.id
                                             ? Color.accentInk
                                             : Color.inkTertiary)
                            .font(.title3)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.label)
                                .font(.bodySerifEmphasis)
                                .foregroundStyle(Color.inkPrimary)
                            Text(model.description)
                                .font(.captionSerif)
                                .foregroundStyle(Color.inkSecondary)
                                .multilineTextAlignment(.leading)
                            Text(model.id)
                                .font(.captionMono)
                                .foregroundStyle(Color.inkTertiary)
                                .padding(.top, 2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                .buttonStyle(.plain)

                if model.id != DeepSeekService.availableModels.last?.id {
                    Divider().background(Color.inkDivider)
                }
            }
        }
        .paperCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Sobre o app", systemImage: "info.circle")
            row("Versão", "1.0")
            row("Modelo atual", DeepSeekService.currentModel.label)
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
