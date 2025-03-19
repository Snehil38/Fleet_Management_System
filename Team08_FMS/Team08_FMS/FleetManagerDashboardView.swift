//
//  FleetManagerHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct FleetManagerDashboardView: View {
    @StateObject private var vehicleManager = VehicleManager()
    @StateObject private var dataManager = CrewDataManager()

    var body: some View {
        TabView {
            VehiclesView(vehicleManager: vehicleManager)
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
            // Crew Tab (only tab)
            FleetCrewManagementView()
            .environmentObject(dataManager)
            .tabItem {
                Label("Crew", systemImage: "person.3")
            }
        }
    }
}

#Preview {
    FleetManagerDashboardView()
}
