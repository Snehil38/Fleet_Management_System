import SwiftUI
import MapKit
import AVFoundation
import CoreLocation

// Import custom components
import SwiftUI

struct RouteOption: Identifiable {
    let id: String
    let name: String
    let eta: String
    let distance: String
    let isRecommended: Bool
}

struct DriverTabView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @StateObject private var tripController = TripDataController.shared

    @State private var showingChatBot = false
    @State private var showingPreTripInspection = false
    @State private var showingPostTripInspection = false
    @State private var showingVehicleDetails = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    @State private var showingProfileView = false
    @State private var isLoading = false
    @State private var loadingError: Error?
    
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
            NavigationView {
                mainContentView
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
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
                                }
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            TripsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Trips")
                }
                .tag(1)
        }
        .task {
            await loadTripsData()
        }
        .refreshable {
            await loadTripsData()
        }
        .sheet(isPresented: $showingChatBot) {
            ChatBotView()
        }
        .sheet(isPresented: $showingProfileView) {
            DriverProfileView()
        }
        .sheet(isPresented: $showingPreTripInspection) {
            VehicleInspectionView(isPreTrip: true) { success in
                if success {
                    if let currentTrip = tripController.currentTrip {
                        tripController.updateTripPreTripStatus(currentTrip, completed: true)
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
                    if let currentTrip = tripController.currentTrip {
                        tripController.updateTripPostTripStatus(currentTrip, completed: true)
                        tripController.markTripAsDelivered(trip: currentTrip)
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
        .sheet(isPresented: $showingDeliveryDetails) {
            if let delivery = selectedDelivery {
                DeliveryDetailsView(delivery: delivery)
            }
        }
        .alert("Error", isPresented: .constant(loadingError != nil)) {
            Button("Retry") {
                Task {
                    await loadTripsData()
                }
            }
            Button("OK") {
                loadingError = nil
            }
        } message: {
            Text(loadingError?.localizedDescription ?? "")
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }

    private func loadTripsData() async {
        isLoading = true
        loadingError = nil
        do {
            try await tripController.loadTrips()
        } catch {
            loadingError = error
            print("Error loading trips: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if availabilityManager.isAvailable {
                    if let currentTrip = tripController.currentTrip {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Current Delivery")
                                .font(.system(size: 22, weight: .bold))
                            
                            currentDeliveryContent
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                        .onTapGesture {
                            showingDeliveryDetails = true
                        }
                    } else {
                        Text("No current deliveries")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    
                    if !tripController.upcomingTrips.isEmpty {
                        Section(header: Text("Upcoming Trips").font(.headline)) {
                            ForEach(tripController.upcomingTrips) { trip in
                                TripCard(trip: trip)
                                    .onTapGesture {
                                        selectedDelivery = DeliveryDetails(
                                            location: trip.destination,
                                            date: (trip.startTime ?? Date()).formatted(date: .numeric, time: .shortened),
                                            status: trip.tripStatus.rawValue,
                                            driver: "Current Driver",
                                            vehicle: trip.vehicleDetails.licensePlate,
                                            notes: trip.notes ?? ""
                                        )
                                        showingDeliveryDetails = true
                                    }
                            }
                        }
                    }
                    
                    if !tripQueue.isEmpty {
                        Section(header: Text("Trip Queue").font(.headline)) {
                            ForEach(tripQueue) { trip in
                                TripCard(trip: trip)
                                    .onTapGesture {
                                        if let currentTrip = tripController.currentTrip {
                                            tripController.markTripAsDelivered(trip: currentTrip)
                                        }
                                        tripController.currentTrip = trip
                                        if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                            tripQueue.remove(at: index)
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Text("You are currently unavailable")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await loadTripsData()
        }
        .sheet(isPresented: $showingDeliveryDetails) {
            if let delivery = selectedDelivery {
                DeliveryDetailsView(delivery: delivery)
            }
        }
        .sheet(isPresented: $showingNavigation) {
            if let currentTrip = tripController.currentTrip {
                NavigationView {
                    RealTimeNavigationView(
                        destination: currentTrip.destinationCoordinate,
                        destinationName: currentTrip.destination,
                        address: currentTrip.address,
                        sourceCoordinate: currentTrip.sourceCoordinate,
                        onDismiss: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingNavigation = false 
                            }
                        }
                    )
                }
            }
        }
    }

    private var navigationOverlay: some View {
        RealTimeNavigationView(
            destination: tripController.currentTrip?.destinationCoordinate ?? CLLocationCoordinate2D(),
            destinationName: tripController.currentTrip?.destination ?? "",
            address: tripController.currentTrip?.address ?? "",
            sourceCoordinate: tripController.currentTrip?.sourceCoordinate ?? CLLocationCoordinate2D(),
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

    private var currentDeliveryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Delivery")
                .font(.system(size: 22, weight: .bold))
            
            currentDeliveryContent
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private var currentDeliveryContent: some View {
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
                        if let currentTrip = tripController.currentTrip {
                            Text(currentTrip.vehicleDetails.licensePlate)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
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
            
            tripLocationsView
            
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
                        
                        Text(selectedRouteEta)
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
                        
                        Text(selectedRouteDistance)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            tripActionButtons
        }
    }

    // Route Information
    private var selectedRouteEta: String {
        if let currentTrip = tripController.currentTrip {
            return availableRoutes.first(where: { $0.id == selectedRouteId })?.eta ?? currentTrip.eta
        }
        return "N/A"
    }

    private var selectedRouteDistance: String {
        if let currentTrip = tripController.currentTrip {
            return availableRoutes.first(where: { $0.id == selectedRouteId })?.distance ?? currentTrip.distance
        }
        return "N/A"
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
            }
        }
        .padding(.vertical, 8)
    }

    private var tripLocationsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let currentTrip = tripController.currentTrip {
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
                            Text(currentTrip.startingPoint)
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
                            Text(currentTrip.destination)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            Text(currentTrip.address)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
    }

    private var tripActionButtons: some View {
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
                        // Remove from current and add to upcoming
                        if let currentTrip = tripController.currentTrip {
                            tripController.upcomingTrips.append(currentTrip)
                            if let nextTrip = tripController.upcomingTrips.first {
                                tripController.currentTrip = nextTrip
                                tripController.upcomingTrips.removeFirst()
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
                        color: tripController.currentTrip?.hasCompletedPreTrip == true ? .blue : .gray
                    ) {
                        if tripController.currentTrip?.hasCompletedPreTrip != true {
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
                        color: tripController.currentTrip?.hasCompletedPreTrip == true ? .gray : .orange
                    ) {
                        if tripController.currentTrip?.hasCompletedPreTrip != true {
                            showingPreTripInspection = true
                        }
                    }
                }
                
                ActionButton(
                    title: "Mark Delivered",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    if let currentTrip = tripController.currentTrip {
                        if !currentTrip.hasCompletedPreTrip {
                            alertMessage = "Please complete pre-trip inspection before marking as delivered"
                            showingAlert = true
                        } else if currentTrip.hasCompletedPostTrip {
                            // Already completed post-trip
                            markCurrentTripDelivered()
                        } else {
                            showingPostTripInspection = true
                        }
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
                            // Make this trip current
                            tripController.currentTrip = trip
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                tripQueue.remove(at: index)
                            }
                        },
                        onDecline: {
                            // Remove from queue and add to upcoming
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                let declinedTrip = tripQueue.remove(at: index)
                                tripController.upcomingTrips.append(declinedTrip)
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

    private var upcomingTripsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Upcoming Trips")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal)

            if tripController.upcomingTrips.isEmpty {
                emptyUpcomingTripsView
            } else {
                upcomingTripsList
            }
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

    private var upcomingTripsList: some View {
        VStack(spacing: 0) {
            ForEach(tripController.upcomingTrips) { trip in
                UpcomingTripRow(
                    trip: trip,
                    onAccept: {
                        if availabilityManager.isAvailable {
                            tripQueue.append(trip)
                            if let index = tripController.upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
                                tripController.upcomingTrips.remove(at: index)
                            }
                        } else {
                            alertMessage = "You must be available to accept new trips"
                            showingAlert = true
                        }
                    },
                    onDecline: {
                        if let index = tripController.upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
                            tripController.upcomingTrips.remove(at: index)
                        }
                    }
                )
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

    private var recentDeliveriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent Deliveries")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal)
            
            if tripController.recentDeliveries.isEmpty {
                emptyRecentDeliveriesView
            } else {
                recentDeliveriesList
            }
        }
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

    private var recentDeliveriesList: some View {
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
        if let currentTrip = tripController.currentTrip, currentTrip.hasCompletedPostTrip {
            // Use the TripDataController to mark the trip as delivered
            tripController.markTripAsDelivered(trip: currentTrip)
            
            // Clear current trip if no more trips
            if tripQueue.isEmpty && tripController.upcomingTrips.isEmpty {
                var updatedTrip = currentTrip
                updatedTrip.tripStatus = .delivered
                tripController.currentTrip = nil
            }
        }
    }

    private func acceptTrip(_ trip: Trip) {
        // If there's no current trip, make this the current trip
        if tripController.currentTrip == nil {
            tripController.currentTrip = trip
            if let index = tripController.upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
                tripController.upcomingTrips.remove(at: index)
            }
        }
    }
}

struct DeliveryRow: View {
    let delivery: DeliveryDetails
    
    var body: some View {
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
        .padding()
    }
}

struct UpcomingTripRow: View {
    let trip: Trip
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var showingDeclineAlert = false
    
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
            
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Add to Queue")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Delivery Information")) {
                    DetailRow(icon: "mappin.circle.fill", title: "Location", value: delivery.location)
                    DetailRow(icon: "calendar", title: "Date", value: delivery.date)
                    DetailRow(icon: "checkmark.circle.fill", title: "Status", value: delivery.status)
                }
                
                Section(header: Text("Driver & Vehicle")) {
                    DetailRow(icon: "person.fill", title: "Driver", value: delivery.driver)
                    DetailRow(icon: "truck.box.fill", title: "Vehicle", value: delivery.vehicle)
                }
                
                Section(header: Text("Notes")) {
                    Text(delivery.notes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                }
                
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
                Button(action: onStart) {
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
        DriverTabView()
    }
} 
