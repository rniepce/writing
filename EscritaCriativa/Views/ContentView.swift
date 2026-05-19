import SwiftUI

struct ContentView: View {
    init() {
        // Tab bar com material translucent + tinta accent para o item selecionado.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            CadernoView()
                .tabItem { Label("Caderno", systemImage: "book.pages") }

            HomeView()
                .tabItem { Label("Hoje", systemImage: "sparkles") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            LibraryView()
                .tabItem { Label("Livros", systemImage: "books.vertical") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(Color.accentInk)
    }
}
