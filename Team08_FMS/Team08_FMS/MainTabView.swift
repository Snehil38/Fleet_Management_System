import SwiftUICore
import SwiftUI
struct MainTabView: View {
    @StateObject private var crewDataManager = CrewDataManager()
    
    var body: some View {
        TabView {
            FleetManagerTabView()
            
            // Other tabs...
        }
        .environmentObject(crewDataManager)
    }
}

//struct FleetManagerTabView: View {
//    @StateObject private var crewDataManager = CrewDataManager()
//    @State private var selectedTab = 0
//    
//    var body: some View {
//        TabView(selection: $selectedTab) {
//            // Dashboard Tab
//            FleetManagerDashboardView()
//                .tabItem {
//                    Image(systemName: "gauge")
//                    Text("Dashboard")
//                }
//                .tag(0)
//            
//            // Crew Management Tab
//            FleetCrewManagementView()
//                .tabItem {
//                    Image(systemName: "person.2.fill")
//                    Text("Crew")
//                }
//                .tag(1)
//        }
//        .environmentObject(crewDataManager)
//    }
//} 
