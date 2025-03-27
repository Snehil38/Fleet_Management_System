import SwiftUI
import MapKit
import AVFoundation
import CoreLocation

// Import custom components
import SwiftUI

struct DriverTabView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @StateObject private var tripController = TripDataController.shared
    let driverId: UUID

    init(driverId: UUID) {
        self.driverId = driverId
    }

    @State private var showingChatBot = false
    @State private var showingPreTripInspection = false
    @State private var showingPostTripInspection = false
    @State private var showingVehicleDetails = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    @State private var showingProfileView = false
    @State private var showingNavigation = false
    @State private var showingDeliveryDetails = false
    @State private var selectedDelivery: DeliveryDetails?
    @State private var isCurrentTripDeclined = false
    @State private var tripQueue: [Trip] = []
    
    // Route Information
    @State private var availableRoutes: [RouteOption] = [
        RouteOption(id: "1", name: "Route 1", eta: "25 mins", distance: "8.5 km", isRecommended: true),
        RouteOption(id: "2", name: "Route 2", eta: "32 mins", distance: "7.8 km", isRecommended: false),
        RouteOption(id: "3", name: "Route 3", eta: "1h 21m", distance: "53 km", isRecommended: false)
    ]
    @State private var selectedRouteId: String = "1"
    
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
        .environmentObject(tripController)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .task {
            // Set the driver ID and load trips
            await tripController.setDriverId(driverId)
            await tripController.refreshTrips()
            TripDataController.shared.startMonitoringRegions()
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                startPoint: .top,
                endPoint: .center
            )
            .edgesIgnoringSafeArea(.all)
            
            NavigationView {
                ZStack {
                    if tripController.isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Loading trips...")
                                .foregroundColor(.gray)
                        }
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                // Current Delivery Card
                                if let currentTrip = tripController.currentTrip,
                                   currentTrip.status == .inProgress && availabilityManager.isAvailable {
                                    currentDeliveryCard(currentTrip)
                                }
                                
                                // Only show upcoming trips and trip queue if available
                                if availabilityManager.isAvailable {
                                    // Trip Queue Section
                                    if !tripQueue.isEmpty {
                                        tripQueueSection
                                    }

                                    // Upcoming Trips Section
                                    VStack(alignment: .leading, spacing: 20) {
                                        Text("Upcoming Trips")
                                            .font(.system(size: 24, weight: .bold))
                                            .padding(.horizontal)

                                        if tripController.upcomingTrips.isEmpty {
                                            emptyUpcomingTripsView
                                        } else {
                                            VStack(spacing: 0) {
                                                ForEach(tripController.upcomingTrips) { trip in
                                                    UpcomingTripRow(trip: trip)
                                                        .environmentObject(tripController)
                                                    if trip.id != tripController.upcomingTrips.last?.id {
                                                        Divider()
                                                            .padding(.horizontal)
                                                    }
                                                }
                                            }
                                            .background(Color(.systemBackground))
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                            .padding(.horizontal)
                                        }
                                    }
                                } else {
                                    // Display message when driver is unavailable
                                    unavailableDriverSection
                                }

                                // Recent Deliveries Section
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        Text("Recent Deliveries")
                                            .font(.system(size: 24, weight: .bold))
                                        
                                        if !tripController.recentDeliveries.isEmpty {
                                            Text("\(tripController.recentDeliveries.count)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color.green)
                                                .cornerRadius(12)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    
                                    if tripController.recentDeliveries.isEmpty {
                                        emptyRecentDeliveriesView
                                    } else {
                                        VStack(spacing: 0) {
                                            ForEach(tripController.recentDeliveries) { delivery in
                                                Button(action: {
                                                    selectedDelivery = delivery
                                                    showingDeliveryDetails = true
                                                }) {
                                                    DeliveryRow(delivery: delivery)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                
                                                if delivery.id != tripController.recentDeliveries.last?.id {
                                                    Divider()
                                                        .padding(.horizontal)
                                                }
                                            }
                                        }
                                        .background(Color(.systemBackground))
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Bottom padding for better scrolling experience
                                Spacer().frame(height: 20)
                            }
                            .padding(.top, 8)
                        }
                        .refreshable {
                            await tripController.refreshTrips()
                        }
                    }
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: {
                                showingChatBot = true
                            }) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                showingProfileView = true
                            }) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                    )
                            }
                        }
                    }
                }
            }
            
            // Full-screen navigation view
            if showingNavigation {
                navigationOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingNavigation)
        .sheet(isPresented: $showingChatBot) {
            ChatBotView()
        }
        .sheet(isPresented: $showingProfileView) {
            DriverProfileView()
        }
        .sheet(isPresented: $showingPreTripInspection) {
            VehicleInspectionView(isPreTrip: true) { success in
                if success {
                    // Only mark as completed if successful
                    if let currentTrip = tripController.currentTrip {
                        Task {
                            do {
                                try await tripController.updateTripInspectionStatus(
                                    tripId: currentTrip.id,
                                    isPreTrip: true,
                                    completed: true
                                )
                            } catch {
                                alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                                showingAlert = true
                            }
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
                    // Only mark as completed if successful
                    if let currentTrip = tripController.currentTrip {
                        Task {
                            do {
                                try await tripController.updateTripInspectionStatus(
                                    tripId: currentTrip.id,
                                    isPreTrip: false,
                                    completed: true
                                )
                                await MainActor.run {
                                    markCurrentTripDelivered()
                                }
                            } catch {
                                alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                    }
                } else {
                    alertMessage = "Please resolve all issues before completing delivery"
                    showingAlert = true
                }
            }
        }
        .sheet(isPresented: $showingVehicleDetails) {
            if let currentTrip = tripController.currentTrip {
                VehicleDetailsView(vehicleDetails: currentTrip.vehicleDetails)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Action Required"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingDeliveryDetails) {
            if let delivery = selectedDelivery {
                DeliveryDetailsView(delivery: delivery)
            }
        }
    }
    
    private var navigationOverlay: some View {
        RealTimeNavigationView(
            destination: tripController.currentTrip?.destinationCoordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            destinationName: tripController.currentTrip?.destination ?? "",
            address: tripController.currentTrip?.address ?? "",
            sourceCoordinate: tripController.currentTrip?.sourceCoordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            onDismiss: { 
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingNavigation = false 
                }
            }
        )
        .edgesIgnoringSafeArea(.all)
        .transition(.move(edge: .bottom))
        .zIndex(1)
    }
    
    private func currentDeliveryCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Delivery")
                .font(.system(size: 22, weight: .bold))
            
            currentDeliveryContent(trip)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func currentDeliveryContent(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Vehicle Details Button
            Button(action: {
                showingVehicleDetails = true
            }) {
                HStack {
                    Image(systemName: "truck.box.fill")
                        .font(.title3)
                    VStack(alignment: .leading) {
                        Text("Vehicle Details")
                            .font(.headline)
                        Text(trip.vehicleDetails.licensePlate)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            tripLocationsView(trip)
            
            // Status Cards - Integrated with route selection
            if !isCurrentTripDeclined {
                HStack(spacing: 10) {
                    // ETA Card - Updates based on selected route
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                )
                            
                            Text("ETA")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text(selectedRouteEta(trip))
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Distance Card - Updates based on selected route
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                )
                            
                            Text("Distance")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text(selectedRouteDistance(trip))
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            tripActionButtons(trip)
        }
    }
    
    // Route Information
    private func selectedRouteEta(_ trip: Trip) -> String {
        availableRoutes.first(where: { $0.id == selectedRouteId })?.eta ?? trip.eta
    }
    
    private func selectedRouteDistance(_ trip: Trip) -> String {
        availableRoutes.first(where: { $0.id == selectedRouteId })?.distance ?? trip.distance
    }
    
    private var routeSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Routes")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableRoutes.sorted(by: { $0.id < $1.id })) { route in
                        Button(action: {
                            selectedRouteId = route.id
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(route.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    if route.isRecommended {
                                        Text("Recommended")
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Label(route.eta, systemImage: "clock")
                                        .font(.system(size: 12))
                                    
                                    Label(route.distance, systemImage: "arrow.left.and.right")
                                        .font(.system(size: 12))
                                }
                            }
                            .padding(10)
                            .frame(width: 160)
                            .background(selectedRouteId == route.id ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedRouteId == route.id ? Color.blue : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Add RouteOption struct
    struct RouteOption: Identifiable {
        let id: String
        let name: String
        let eta: String
        let distance: String
        let isRecommended: Bool
    }
    
    private func tripLocationsView(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Simplified container with integrated progress line
            VStack(alignment: .leading, spacing: 20) {
                // Starting Point section
                HStack(alignment: .center, spacing: 18) {
                    // Container for the circle and progress line
                    ZStack(alignment: .top) {
                        // Blue circle
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                        
                        // Progress line from starting point to destination
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.gray.opacity(0.4)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: 2, height: 75)
                            .offset(y: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starting Point")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(trip.startingPoint)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Mumbai, Maharashtra")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Destination section - no spacing adjustment needed with the improved layout
                HStack(alignment: .top, spacing: 18) {
                    // Red location pin
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                        .offset(x: -2) // Align with the line
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Destination")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(trip.destination)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        Text(trip.address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
    }
    
    private func tripActionButtons(_ trip: Trip) -> some View {
        VStack(spacing: 10) {
            if isCurrentTripDeclined {
                // Show Accept/Decline buttons for declined trip
                HStack(spacing: 10) {
                    ActionButton(
                        title: "Accept Trip",
                        icon: "checkmark",
                        color: .green
                    ) {
                        isCurrentTripDeclined = false
                    }
                    
                    ActionButton(
                        title: "Decline Trip",
                        icon: "xmark",
                        color: .red
                    ) {
                        Task {
                            // Remove from current and add to upcoming
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                tripQueue.remove(at: index)
                            }
                        }
                    }
                }
            } else {
                // Show regular action buttons in a more compact layout
                HStack(spacing: 10) {
                    ActionButton(
                        title: "Start\nNavigation",
                        icon: "location.fill",
                        color: trip.hasCompletedPreTrip ? .blue : .gray
                    ) {
                        if !trip.hasCompletedPreTrip {
                            alertMessage = "Please complete pre-trip inspection before starting navigation"
                            showingAlert = true
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingNavigation = true
                            }
                        }
                    }
                    
                    ActionButton(
                        title: "Pre-Trip Inspection",
                        icon: "checklist",
                        color: trip.hasCompletedPreTrip ? .gray : .orange
                    ) {
                        if !trip.hasCompletedPreTrip {
                            showingPreTripInspection = true
                        }
                    }
                }
                
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
        }
    }
    
    private var tripQueueSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trip Queue")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(tripQueue) { trip in
                    QueuedTripRow(
                        trip: trip,
                        onStart: {
                            Task {
                                do {
                                    try await tripController.startTrip(trip: trip)
                                    if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                        tripQueue.remove(at: index)
                                    }
                                } catch {
                                    alertMessage = "Failed to start trip: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        },
                        onDecline: {
                            // Remove from queue
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                tripQueue.remove(at: index)
                            }
                        }
                    )
                    if trip.id != tripQueue.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
        }
    }
    
    private var emptyUpcomingTripsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Upcoming Trips")
                .font(.headline)
            Text("Check back later for new assignments")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var emptyRecentDeliveriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Recent Deliveries")
                .font(.headline)
            Text("Completed deliveries will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var unavailableDriverSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "car.fill.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding()
            
            Text("You are currently unavailable for trips")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Your status will automatically change back to available tomorrow.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func markCurrentTripDelivered() {
        if let trip = tripController.currentTrip, trip.hasCompletedPostTrip {
            // Create a Task to handle the async operation
            Task {
                do {
                    // First update the trip inspection status in Supabase if needed
                    if !trip.hasCompletedPreTrip {
                        try await tripController.updateTripInspectionStatus(
                            tripId: trip.id,
                            isPreTrip: true,
                            completed: true
                        )
                    }
                    
                    if !trip.hasCompletedPostTrip {
                        try await tripController.updateTripInspectionStatus(
                            tripId: trip.id,
                            isPreTrip: false,
                            completed: true
                        )
                    }
                    
                    // Then mark the trip as delivered in Supabase
                    try await tripController.markTripAsDelivered(trip: trip)
                    print("Trip marked as delivered successfully")
                    
                    // Explicitly refresh trips to ensure data is updated
                    await tripController.refreshTrips()
                    
                    // If there are no more trips, move to the next one
                    if tripController.currentTrip == nil {
                        if !tripQueue.isEmpty {
                            // Take the next trip from the queue
                            let nextTrip = tripQueue.removeFirst()
                            Task {
                                try await tripController.startTrip(trip: nextTrip)
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to mark trip as delivered: \(error.localizedDescription)"
                        showingAlert = true
                    }
                    print("Error marking trip as delivered: \(error)")
                }
            }
        } else {
            // If pre-trip not completed, show alert
            if let trip = tripController.currentTrip, !trip.hasCompletedPreTrip {
                alertMessage = "Please complete pre-trip inspection before marking as delivered"
                showingAlert = true
            }
            // If post-trip not completed, show post-trip inspection
            else if let trip = tripController.currentTrip, !trip.hasCompletedPostTrip {
                showingPostTripInspection = true
            } else {
                print("Cannot mark as delivered: trip is nil")
            }
        }
    }
    
    private func acceptTrip(_ trip: Trip) {
        // If there's no current trip, make this the current trip
        if tripController.currentTrip?.status != .inProgress {
            Task {
                do {
                    try await tripController.startTrip(trip: trip)
                } catch {
                    alertMessage = "Failed to start trip: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

struct DeliveryRow: View {
    let delivery: DeliveryDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(delivery.location)
                        .font(.headline)
                    Text(delivery.date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(delivery.status)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            // Get first line of notes for display as preview
            if let firstLine = delivery.notes.split(separator: "\n").first {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text(String(firstLine).replacingOccurrences(of: "Trip: ", with: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .padding(.leading, 16)
            }
            
            // Display the vehicle info
            HStack(spacing: 6) {
                Image(systemName: "car.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text(delivery.vehicle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.leading, 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct UpcomingTripRow: View {
    let trip: Trip
    @EnvironmentObject var tripController: TripDataController
    @State private var showingAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(trip.destination)
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        do {
                            try await tripController.startTrip(trip: trip)
                        } catch {
                            errorMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }) {
                    Text("Start Trip")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            
            if let notes = trip.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let pickup = trip.pickup {
                Text("Pickup: \(pickup)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct VehicleDetailItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
}

struct VehicleDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let vehicleDetails: Vehicle
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Information")) {
                    DetailRow(icon: "car.fill", title: "Vehicle Type", value: vehicleDetails.vehicleType.rawValue)
                    DetailRow(icon: "number", title: "License Plate", value: vehicleDetails.licensePlate)
                }
                
                Section(header: Text("Additional Information")) {
                    DetailRow(icon: "calendar", title: "Last Maintenance", value: "2024-03-15")
                    DetailRow(icon: "gauge", title: "Mileage", value: "45,678 mi")
                    DetailRow(icon: "fuelpump.fill", title: "Fuel Level", value: "75%")
                }
                
                Section(header: Text("Status")) {
                    DetailRow(icon: "checkmark.circle.fill", title: "Vehicle Status", value: "Active")
                    DetailRow(icon: "wrench.fill", title: "Maintenance Due", value: "In 2 weeks")
                    DetailRow(icon: "exclamationmark.triangle.fill", title: "Alerts", value: "None")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct NavigationStep: View {
    let direction: String
    let distance: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(direction)
                    .font(.headline)
                Text(distance)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DeliveryDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let delivery: DeliveryDetails
    
    // Parse notes to get structured information
    private var parsedNotes: [String: String] {
        var result = [String: String]()
        let lines = delivery.notes.split(separator: "\n")
        
        for line in lines where line.contains(":") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            List {
                // Trip Info Section
                Section(header: Text("Trip Information")) {
                    if let tripName = parsedNotes["Trip"] {
                        DetailRow(icon: "shippingbox.fill", title: "Trip ID", value: tripName)
                    }
                    DetailRow(icon: "mappin.circle.fill", title: "Destination", value: delivery.location)
                    DetailRow(icon: "calendar", title: "Delivery Date", value: delivery.date)
                    DetailRow(icon: "checkmark.circle.fill", title: "Status", value: delivery.status)
                }
                
                // Route Details Section
                Section(header: Text("Route Details")) {
                    if let startPoint = parsedNotes["From"] {
                        DetailRow(icon: "arrow.up.circle.fill", title: "Starting Point", value: startPoint)
                    }
                    if let distance = parsedNotes["Distance"] {
                        DetailRow(icon: "arrow.left.and.right", title: "Distance", value: distance)
                    }
                }
                
                // Cargo Section
                Section(header: Text("Cargo Information")) {
                    if let cargo = parsedNotes["Cargo"] {
                        DetailRow(icon: "box.truck.fill", title: "Cargo Type", value: cargo)
                    }
                }
                
                // Vehicle & Driver Info Section
                Section(header: Text("Driver & Vehicle")) {
                    DetailRow(icon: "person.fill", title: "Driver", value: delivery.driver)
                    DetailRow(icon: "truck.box.fill", title: "Vehicle", value: delivery.vehicle)
                }
                
                // Additional Notes Section (original notes minus structured info)
                let filteredNotes = delivery.notes.split(separator: "\n")
                    .filter { !$0.contains("Trip:") && !$0.contains("Cargo:") && !$0.contains("Distance:") && !$0.contains("From:") }
                    .joined(separator: "\n")
                
                if !filteredNotes.isEmpty {
                    Section(header: Text("Additional Notes")) {
                        Text(filteredNotes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                    }
                }
                
                // Proof of Delivery Section
                Section(header: Text("Proof of Delivery")) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Delivery Receipt")
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "signature")
                        Text("Customer Signature")
                        Spacer()
                        Image(systemName: "eye")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Delivery Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct QueuedTripRow: View {
    let trip: Trip
    let onStart: () -> Void
    let onDecline: () -> Void
    @State private var showingDeclineAlert = false
    @StateObject private var tripController = TripDataController.shared
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(trip.destination)
                        .font(.headline)
                    Text(trip.address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.eta)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text(trip.distance)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("In Queue")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Text("Ready to start")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        do {
                            try await tripController.startTrip(trip: trip)
                            onStart()
                        } catch {
                            alertMessage = error.localizedDescription
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Trip")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { showingDeclineAlert = true }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .alert(isPresented: $showingDeclineAlert) {
            Alert(
                title: Text("Decline Trip"),
                message: Text("Are you sure you want to decline trip \(trip.name)?"),
                primaryButton: .destructive(Text("Decline")) {
                    onDecline()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapPolyline: View {
    let coordinates: [CLLocationCoordinate2D]
    let strokeColor: Color
    let lineWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Start at the first coordinate
                let startPoint = CGPoint(
                    x: 0,
                    y: geometry.size.height / 2
                )
                path.move(to: startPoint)
                
                // Draw a line to the end point
                let endPoint = CGPoint(
                    x: geometry.size.width,
                    y: geometry.size.height / 2
                )
                path.addLine(to: endPoint)
            }
            .stroke(strokeColor, lineWidth: lineWidth)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        DriverTabView(driverId: UUID())
    }
} 
