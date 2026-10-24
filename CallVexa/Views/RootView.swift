import SwiftUI

struct RootView: View {
    @ObservedObject var authManager = AuthSessionManager.shared
    
    var body: some View {
        // Direct Agent launch — zero login blocker screen
        AgentTabView()
            .preferredColorScheme(.dark)
    }
}

// MARK: - Dedicated Agent Tab View

struct AgentTabView: View {
    @State private var selectedTab: Int = 0
    
    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.cvSurface)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AgentWorkstationView()
                .tabItem {
                    Label("Agent", systemImage: "phone.fill")
                }
                .tag(0)
            
            CallHistoryView()
                .tabItem {
                    Label("Calls", systemImage: "clock.fill")
                }
                .tag(1)
            
            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
                .tag(2)
            
            MessagesHubView()
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)
        }
        .tint(.cvPrimaryLight)
    }
}
