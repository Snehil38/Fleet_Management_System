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
}
