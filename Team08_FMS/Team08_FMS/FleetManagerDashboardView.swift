//
//  FleetManagerHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct FleetManagerDashboardView: View {
    @StateObject private var vehicleManager = VehicleManager()

    var body: some View {
        TabView {
            VehiclesView(vehicleManager: vehicleManager)
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }

        }
    }
}

#Preview {
    FleetManagerDashboardView()
}
