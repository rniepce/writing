import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Hoje", systemImage: "sparkles") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            LibraryView()
                .tabItem { Label("Biblioteca", systemImage: "books.vertical") }

            SettingsView()
                .tabItem { Label("Config", systemImage: "gearshape") }
        }
    }
}
