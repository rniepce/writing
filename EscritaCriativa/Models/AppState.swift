import Foundation
import Observation
import SwiftUI

/// Estado compartilhado entre tabs (seleção de tab + handoffs).
/// Vive no nível do app, injetado via `.environment(_:)`.
@Observable
final class AppState {
    enum Tab: Hashable {
        case caderno, hoje, chat, livros, ajustes
    }

    /// Tab atualmente visível no TabView.
    var selectedTab: Tab = .caderno

    /// Texto anexado pra próxima mensagem do Chat — tipicamente o corpo de
    /// uma nota mandada via "Pedir feedback ao chat". Some depois que a
    /// mensagem é enviada ou o usuário fecha o chip.
    var pendingChatContext: String? = nil
    /// Rótulo curto pra mostrar no chip (ex: título da nota, "Trecho do Caderno").
    var pendingChatContextLabel: String? = nil

    /// Sugestão de prompt pra pré-preencher o campo de input do chat.
    /// Some assim que o ChatView consome.
    var pendingChatPromptDraft: String? = nil

    /// Conveniência: limpa todo o estado de attachment.
    func clearChatAttachment() {
        pendingChatContext = nil
        pendingChatContextLabel = nil
    }
}
