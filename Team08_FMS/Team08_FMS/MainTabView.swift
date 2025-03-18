import SwiftUI

struct MainTabView: View {
    @StateObject private var dataManager = CrewDataManager()
    
    var body: some View {
        TabView {
            // Crew Tab (only tab)
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Crew", systemImage: "person.3")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
} 