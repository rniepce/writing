import SwiftUI
import SwiftData

@main
struct EscritaCriativaApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Tip.self,
            Book.self,
            BookChunk.self,
            ChatMessage.self,
            Note.self,
        ])
        return try! ModelContainer(for: schema)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onAppear {
                    TipsService.seedIfNeeded(context: container.mainContext)
                }
        }
    }
}
