import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.selectedTab) {
            CadernoView()
                .tabItem { Label("Caderno", systemImage: "book.pages") }
                .tag(AppState.Tab.caderno)

            HomeView()
                .tabItem { Label("Hoje", systemImage: "sparkles") }
                .tag(AppState.Tab.hoje)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(AppState.Tab.chat)

            LibraryView()
                .tabItem { Label("Livros", systemImage: "books.vertical") }
                .tag(AppState.Tab.livros)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(AppState.Tab.ajustes)
        }
        .tint(Color.accentInk)
    }
}
