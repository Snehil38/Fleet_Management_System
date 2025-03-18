//
//  ContentView.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = SupabaseDataController.shared  // Observing changes

    var body: some View {
        VStack {
            if !auth.isAuthenticated {
                LoginView()
            } else {
                switch auth.userRole {
                case "fleet_manager":
                    FleetManagerHomeScreen()
                case "driver":
                    DriverHomeScreen()
                case "maintenance_personnel":
                    MaintenancePersonnelHomeScreen()
                default:
                    LoginView() // Handles unknown role case
                }
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated) // Smooth transition
    }
}

#Preview {
    ContentView()
}
