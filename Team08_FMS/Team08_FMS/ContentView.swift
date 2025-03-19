//
//  ContentView.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

struct ContentView: View {
    @State private var userRole: UserRole = .fleetManager // or however you determine the role
    
    var body: some View {
        Group {
            switch userRole {
            case .fleetManager:
                FleetManagerTabView()
            case .driver:
                // Placeholder for driver view until implemented
                Text("Driver View Coming Soon")
            case .maintenance:
                // Placeholder for maintenance view until implemented
                Text("Maintenance View Coming Soon")
            }
        }
    }
}

enum UserRole {
    case fleetManager
    case driver
    case maintenance
}

struct FleetManagerTabView: View {
    @StateObject private var crewDataManager = CrewDataManager()
    @StateObject private var vehicleManager = VehicleManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            FleetManagerDashboardView()
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Vehicles Tab
            VehiclesView(vehicleManager: vehicleManager)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehicles")
                }
                .tag(1)
            
            // Crew Management Tab
            FleetCrewManagementView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Crew")
                }
                .tag(2)
        }
        .environmentObject(crewDataManager)
        .environmentObject(vehicleManager)
    }
}

#Preview {
    ContentView()
}
