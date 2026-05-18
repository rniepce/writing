import Foundation

enum DeepSeekError: LocalizedError {
    case missingAPIKey
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Configure sua chave de API do DeepSeek nas Configurações."
        case .badResponse(let code):
            return "Erro na API do DeepSeek (HTTP \(code))."
        }
    }
}

final class DeepSeekService {
    static let shared = DeepSeekService()
    private init() {}

    private let baseURL = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    private let model = "deepseek-chat"
    private let systemPrompt = """
        Você é um assistente especializado em escrita criativa de ficção literária. \
        Ajude com técnicas narrativas, desenvolvimento de personagens, estrutura de enredo, \
        diálogo, ponto de vista, ritmo e outros elementos do craft. \
        Seja direto, prático e cite exemplos quando relevante. Responda sempre em português.
        """

    func stream(
        userMessage: String,
        history: [ChatMessage],
        ragContext: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = KeychainService.load(account: KeychainService.deepSeekKeyAccount),
                          !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
                    else {
                        throw DeepSeekError.missingAPIKey
                    }

                    var apiMessages: [[String: String]] = [
                        ["role": "system", "content": systemPrompt]
                    ]

                    if let context = ragContext {
                        apiMessages.append([
                            "role": "system",
                            "content": "Contexto relevante dos livros de referência:\n\(context)"
                        ])
                    }

                    for msg in history.suffix(10) {
                        apiMessages.append(["role": msg.role, "content": msg.content])
                    }
                    apiMessages.append(["role": "user", "content": userMessage])

                    let body: [String: Any] = [
                        "model": model,
                        "messages": apiMessages,
                        "stream": true,
                        "max_tokens": 1024
                    ]

                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard statusCode == 200 else {
                        throw DeepSeekError.badResponse(statusCode)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              line != "data: [DONE]",
                              let data = line.dropFirst(6).data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let token = delta["content"] as? String
                        else { continue }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
