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
    @State private var refreshTask: Task<Void, Never>?

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
            
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Crew")
                }
        }
        .task {
            // Initial load
            vehicleManager.loadVehicles()
            CrewDataController.shared.update()
            listenForGeofenceEvents()
            await refreshData()
            
            // Start periodic refresh
//            refreshTask = Task {
//                while !Task.isCancelled {
//                    try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
//                    await refreshData()
//                }
//            }
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }
    
    private func refreshData() async {
        await TripDataController.shared.refreshAllTrips()
        await SupabaseDataController.shared.fetchGeofenceEvents()
        await dataManager.checkAndUpdateDriverTripStatus()
        await dataManager.checkAndUpdateVehicleStatus(vehicleManager: vehicleManager)
    }
    
    func listenForGeofenceEvents() {
        SupabaseDataController.shared.subscribeToGeofenceEvents()
    }
}

#Preview {
    FleetManagerTabView()
}
