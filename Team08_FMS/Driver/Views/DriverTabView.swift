.sheet(isPresented: $showingPreTripInspection) {
    VehicleInspectionView(isPreTrip: true) { success in
        if success {
            // Only mark as completed if successful
            if let updatedTrip = currentTrip {
                Task {
                    do {
                        try await tripController.updateTripInspectionStatus(
                            tripId: updatedTrip.id,
                            isPreTrip: true,
                            completed: true
                        )
                        // Update local state after Supabase is updated
                        if var trip = currentTrip {
                            trip.hasCompletedPreTrip = true
                            currentTrip = trip
                        }
                    } catch {
                        alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } else {
            // If not successful, display alert but don't mark as completed
            alertMessage = "Please resolve all issues before starting the trip"
            showingAlert = true
        }
    }
}
.sheet(isPresented: $showingPostTripInspection) {
    VehicleInspectionView(isPreTrip: false) { success in
        if success {
            // Only mark as completed and mark delivered if successful
            if var updatedTrip = currentTrip {
                Task {
                    do {
                        try await tripController.updateTripInspectionStatus(
                            tripId: updatedTrip.id,
                            isPreTrip: false,
                            completed: true
                        )
                        // Update local state after Supabase is updated
                        if var trip = currentTrip {
                            trip.hasCompletedPostTrip = true
                            currentTrip = trip
                            // Use Task to call the async method
                            Task {
                                await MainActor.run {
                                    markCurrentTripDelivered()
                                }
                            }
                        }
                    } catch {
                        alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } else {
            // If not successful, display alert but don't mark as completed
            alertMessage = "Please resolve all issues before completing delivery"
            showingAlert = true
        }
    }
}

// ... existing code ...

private func markCurrentTripDelivered() {
    if let trip = currentTrip, trip.hasCompletedPostTrip {
        // Create a Task to handle the async operation
        Task {
            do {
                // First mark the trip as delivered in Supabase
                try await tripController.markTripAsDelivered(trip: trip)
                print("Trip marked as delivered successfully")
                
                // The data will be updated in the controller automatically
                // when the refresh is completed in markTripAsDelivered
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to mark trip as delivered: \(error.localizedDescription)"
                    showingAlert = true
                }
                print("Error marking trip as delivered: \(error)")
            }
        }
    } else {
        print("Cannot mark as delivered: trip is nil or post-trip inspection not completed")
    }
}

struct DriverTabView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @StateObject private var tripController = TripDataController.shared

    // ... existing state properties ...
    
    @State private var isRefreshing = false
    @State private var lastRefreshTime = Date()
    private let minimumRefreshInterval: TimeInterval = 5 // Minimum seconds between refreshes
    
    var body: some View {
        TabView(selection: $selectedTab) {
            mainContentView
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            NavigationView {
                TripsView()
            }
            .tabItem {
                Label("Trips", systemImage: "car.fill")
            }
            .tag(1)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .onChange(of: tripController.currentTrip) { newTrip in
            currentTrip = newTrip
        }
        .onChange(of: tripController.upcomingTrips) { newTrips in
            upcomingTrips = newTrips
        }
        .onChange(of: tripController.recentDeliveries) { newDeliveries in
            recentDeliveries = newDeliveries
        }
        .onAppear {
            refreshTripsIfNeeded()
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // ... existing background gradient ...
            
            NavigationView {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ... existing content ...
                        ActionButton(
                            title: "Mark Delivered",
                            icon: "checkmark.circle.fill",
                            color: .green
                        ) {
                            if !trip.hasCompletedPreTrip {
                                alertMessage = "Please complete pre-trip inspection before marking as delivered"
                                showingAlert = true
                            } else if trip.hasCompletedPostTrip {
                                // Already completed post-trip
                                // Use Task to handle the async call
                                Task {
                                    await MainActor.run {
                                        markCurrentTripDelivered()
                                    }
                                }
                            } else {
                                showingPostTripInspection = true
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await refreshTrips()
                }
                .toolbar {
                    // ... existing toolbar items ...
                }
            }
            
            if isRefreshing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        // ... existing modifiers ...
    }
    
    private func refreshTripsIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) >= minimumRefreshInterval {
            Task {
                await refreshTrips()
            }
        }
    }
    
    private func refreshTrips() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { 
            isRefreshing = false
            lastRefreshTime = Date()
        }
        
        do {
            try await tripController.refreshTrips()
        } catch {
            alertMessage = "Failed to refresh trips: \(error.localizedDescription)"
            showingAlert = true
        }
    }
} 