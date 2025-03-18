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
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(2)
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

struct ProfileView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var showingLicensePhoto = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                            .padding(.top)
                        
                        Text("John Anderson")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Professional Driver")
                            .foregroundColor(.gray)
                        
                        Toggle("Available for Trips", isOn: $availabilityManager.isAvailable)
                            .padding(.vertical)
                            .onChange(of: availabilityManager.isAvailable) { oldValue, newValue in
                                let feedback = UINotificationFeedbackGenerator()
                                feedback.notificationOccurred(.success)
                            }
                            .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section(header: Text("Contact Information")) {
                    LabeledContent("Phone", value: "+1 (555) 123-4567")
                    LabeledContent("Email", value: "john.anderson@company.com")
                }
                
                Section(header: Text("License Information")) {
                    Button(action: {
                        showingLicensePhoto = true
                    }) {
                        HStack {
                            Text("Driver License")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    LabeledContent("License Number", value: "DL12345678")
                    LabeledContent("Expiry Date", value: "07/11/2025")
                }
                
                Section(header: Text("Experience & Expertise")) {
                    LabeledContent("Experience", value: "5 Years")
                    LabeledContent("Vehicle Type", value: "Heavy Truck")
                    LabeledContent("Specialized Terrain", value: "Mountain, Highway")
                }
                
                Section {
                    Button(action: {
                        // Implement logout
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingLicensePhoto) {
                NavigationView {
                    VStack {
                        Image(systemName: "person.text.rectangle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("Driver License Photo")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .navigationBarItems(trailing: Button("Done") {
                        showingLicensePhoto = false
                    })
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
