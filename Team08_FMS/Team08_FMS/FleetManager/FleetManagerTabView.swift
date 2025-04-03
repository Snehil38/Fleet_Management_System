//
//  FleetManagerHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

// Renamed to avoid conflict with ChatViewModel
struct TestNotificationPayload: Codable {
    let message: String
    let type: String
    let created_at: String
    let is_read: Bool
}

struct FleetManagerTabView: View {
    @StateObject private var vehicleManager = VehicleManager()
    @StateObject private var dataManager = CrewDataController.shared
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @State private var refreshTask: Task<Void, Never>?
    @State private var showingNotifications = false

    var body: some View {
        TabView {
            FleetManagerDashboardTabView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Dashboard")
                }
            
            FleetTripsView()
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Trips")
                }
            
            VehiclesView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehicles")
                }
            
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Crew")
                }
        }
        .notificationBanner(viewModel: notificationsViewModel, showingNotifications: $showingNotifications)
        .onChange(of: notificationsViewModel.showBanner) { _, newValue in
            print("🔔 Banner state changed: \(newValue)")
            if let notification = notificationsViewModel.currentBannerNotification {
                print("🔔 Current notification: \(notification.message)")
            }
        }
        .onChange(of: showingNotifications) { _, newValue in
            print("🔔 Showing notifications sheet: \(newValue)")
        }
        .task {
            // Initial load
            print("🔄 FleetManagerTabView: Loading initial data...")
            vehicleManager.loadVehicles()
            CrewDataController.shared.update()
            listenForGeofenceEvents()
            await refreshData()
            
            // Debug: Test notification
            print("🔔 Setting up test notification...")
            await testNotification()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
        .sheet(isPresented: $showingNotifications) {
            AlertsView()
                .environmentObject(notificationsViewModel)
        }
    }
    
    private func refreshData() async {
        await TripDataController.shared.refreshAllTrips()
        await SupabaseDataController.shared.fetchGeofenceEvents()
        await dataManager.checkAndUpdateDriverTripStatus()
    }
    
    func listenForGeofenceEvents() {
        SupabaseDataController.shared.subscribeToGeofenceEvents()
    }
    
    // Debug function to test notification banner
    private func testNotification() async {
        do {
            print("🔔 Creating test notification...")
            let notification = TestNotificationPayload(
                message: "Test notification banner",
                type: "test",
                created_at: ISO8601DateFormatter().string(from: Date()),
                is_read: false
            )
            
            let response = try await SupabaseDataController.shared.supabase.database
                .from("notifications")
                .insert(notification)
                .select()
                .single()
                .execute()
            
            print("✅ Test notification created successfully")
        } catch {
            print("❌ Failed to create test notification: \(error)")
        }
    }
}

#Preview {
    FleetManagerTabView()
        .environmentObject(SupabaseDataController.shared)
}
