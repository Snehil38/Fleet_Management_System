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
                RoleSelectionView()
            } else {
                if let userID = auth.userID, auth.isGenPass {
                    ResetGeneratedPasswordView(userID: userID)
                } else {
                    switch auth.userRole {
                    case "fleet_manager":
                        FleetManagerDashboardView()
                    case "driver":
                        HomeView()
                    case "maintenance_personnel":
                        MaintenancePersonnelDashboardView()
                    default:
                        RoleSelectionView() // Handles unknown role case
                    }
                }
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated) // Smooth transition
    }
}

#Preview {
    ContentView()
}
