//
//  FleetManagerHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct FleetManagerTabView: View {
    @StateObject private var vehicleManager = VehicleManager()
    @StateObject private var dataManager = CrewDataController.shared

    var body: some View {
        TabView {
            FleetManagerDashboardTabView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            VehiclesView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
            // Crew Tab (only tab)
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Label("Crew", systemImage: "person.3")
                }
        }
        .task {
            vehicleManager.loadVehicles()
        }
    }
}

#Preview {
    FleetManagerTabView()
}
