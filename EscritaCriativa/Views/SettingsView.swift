import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("DeepSeek API") {
                    SecureField("Chave de API", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Salvar chave") {
                        KeychainService.save(value: apiKey, forAccount: KeychainService.deepSeekKeyAccount)
                        showSavedAlert = true
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    Text("Sua chave é armazenada com segurança no Keychain do iPhone e nunca é enviada para outros servidores além do DeepSeek.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Sobre") {
                    LabeledContent("Versão", value: "1.0")
                    LabeledContent("Modelo LLM", value: "deepseek-chat")
                    LabeledContent("Busca nos livros", value: "BM25 on-device")
                }
            }
            .navigationTitle("Configurações")
            .onAppear {
                apiKey = KeychainService.load(account: KeychainService.deepSeekKeyAccount) ?? ""
            }
            .alert("Chave salva!", isPresented: $showSavedAlert) {
                Button("OK") {}
            }
        }
    }
}
