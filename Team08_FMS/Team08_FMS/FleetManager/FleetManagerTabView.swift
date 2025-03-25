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
                    Image(systemName: "gauge")
                    Text("Dashboard")
                }
            
            FleetTripsView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Trips")
                }
            
            VehiclesView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehicles")
                }
            // Crew Tab (only tab)
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Crew")
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
