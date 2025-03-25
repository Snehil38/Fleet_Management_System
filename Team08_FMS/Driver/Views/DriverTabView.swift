.sheet(isPresented: $showingPreTripInspection) {
    VehicleInspectionView(isPreTrip: true) { success in
        if success {
            Task {
                do {
                    try await tripController.updateTripInspectionStatus(
                        tripId: currentTrip.id,
                        isPreTrip: true,
                        completed: true
                    )
                    // Only update local state after successful Supabase update
                    currentTrip.hasCompletedPreTrip = true
                } catch {
                    alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            alertMessage = "Please resolve all issues before starting the trip"
            showingAlert = true
        }
    }
}
.sheet(isPresented: $showingPostTripInspection) {
    VehicleInspectionView(isPreTrip: false) { success in
        if success {
            Task {
                do {
                    try await tripController.updateTripInspectionStatus(
                        tripId: currentTrip.id,
                        isPreTrip: false,
                        completed: true
                    )
                    // Only update local state after successful Supabase update
                    currentTrip.hasCompletedPostTrip = true
                    markCurrentTripDelivered()
                } catch {
                    alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            alertMessage = "Please resolve all issues before completing delivery"
            showingAlert = true
        }
    }
}

// ... existing code ...

private func markCurrentTripDelivered() {
    if currentTrip.hasCompletedPostTrip {
        // Use the TripDataController to mark the trip as delivered
        tripController.markTripAsDelivered(trip: currentTrip)
        
        // The UI will be updated automatically when fetchTrips() completes
        // in the markTripAsDelivered method
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