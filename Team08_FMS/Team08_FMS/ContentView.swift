//
//  ContentView.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = SupabaseDataController.shared  // Observing changes
    @State private var isLoggedIn = false
    
    var body: some View {
        VStack {
            if !auth.isAuthenticated {
                LoginView()
            } else {
                switch auth.userRole {
//                case "fleet_manager":
//                    FleetManagerDashboardView()
                case "driver":
                    MainTabView() // Use MainTabView for driver role
//                case "maintenance_personnel":
//                    MaintenancePersonnelDashboardView()
                default:
                    LoginView() // Handles unknown role case
                }
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated) // Smooth transition
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "location.fill")
                    Text("Navigation")
                }
                .tag(0)
            
            TripsView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Trips")
                }
                .tag(1)
        }
    }
}

struct TripsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Upcoming Trips")) {
                    ForEach(0..<3) { _ in
                        TripRow(
                            destination: "Los Angeles Port Terminal",
                            address: "456 Enterprise Street, Tech District",
                            date: "Tomorrow, 9:00 AM",
                            status: "Scheduled"
                        )
                    }
                }
                
                Section(header: Text("Completed Trips")) {
                    ForEach(0..<5) { _ in
                        TripRow(
                            destination: "San Francisco Port",
                            address: "789 Bay Area Blvd",
                            date: "Yesterday, 2:30 PM",
                            status: "Completed"
                        )
                    }
                }
            }
            .navigationTitle("My Trips")
        }
    }
}

struct TripRow: View {
    let destination: String
    let address: String
    let date: String
    let status: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(destination)
                .font(.headline)
            Text(address)
                .font(.subheadline)
                .foregroundColor(.gray)
            HStack {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status == "Completed" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(status == "Completed" ? .green : .blue)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
