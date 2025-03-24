//
//  ContentView.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: SupabaseDataController

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
                        FleetManagerTabView()
                    case "driver":
                        DriverTabView()
                    case "maintenance_personnel":
                        MaintenancePersonnelTabView()
                    default:
                        RoleSelectionView()
                    }
                }
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
        .task {
            await auth.autoLogin()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseDataController.shared)
        .environmentObject(VehicleManager.shared)
        .environmentObject(CrewDataController.shared)
}
