import SwiftUI
import CoreLocation

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    @State private var selectedFilter = 0
    
    var currentTrips: [Trip] {
        if let currentTrip = tripController.currentTrip {
            return [currentTrip]
        }
        return []
    }
    
    var upcomingTrips: [Trip] {
        return tripController.upcomingTrips
    }
    
    var completedTrips: [Trip] {
        return tripController.recentDeliveries.compactMap { delivery in
            // Convert DeliveryDetails back to Trip format
            Trip(
                id: delivery.id,
                name: delivery.notes.components(separatedBy: "\n").first?.replacingOccurrences(of: "Trip: ", with: "") ?? "Unknown",
                destination: delivery.location,
                address: delivery.location,
                eta: "",
                distance: "",
                status: .delivered,
                hasCompletedPreTrip: true,
                hasCompletedPostTrip: true,
                vehicleDetails: Vehicle.mockVehicle(licensePlate: delivery.vehicle),
                sourceCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                destinationCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                startingPoint: "",
                notes: delivery.notes,
                startTime: nil,
                endTime: nil
            )
        }
    }
    
    var filteredTrips: [Trip] {
        switch selectedFilter {
        case 0: // Current
            return currentTrips
        case 1: // Upcoming
            return upcomingTrips
        case 2: // Completed
            return completedTrips
        default:
            return []
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter control
                Picker("Trip Filter", selection: $selectedFilter) {
                    Text("Current").tag(0)
                    Text("Upcoming").tag(1)
                    Text("Completed").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Trip counts
                HStack(spacing: 16) {
                    ForEach(0..<3) { index in
                        let count = getTripCount(for: index)
                        let label = ["Current", "Upcoming", "Completed"][index]
                        
                        VStack {
                            Text("\(count)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(label)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedFilter == index ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedFilter = index
                        }
                    }
                }
                .padding(.horizontal)
                
                // Simple header section
                HStack {
                    Text(getHeaderTitle())
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action for adding a new trip
                    }) {
                        Label("Add Trip", systemImage: "plus")
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Trip list
                if filteredTrips.isEmpty {
                    EmptyTripsView(filterType: selectedFilter)
                        .onAppear {
                            print("No trips to display for selected filter")
                        }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trips")
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                if let error = tripController.error {
                    switch error {
                    case .fetchError(let message),
                         .decodingError(let message),
                         .vehicleError(let message),
                         .updateError(let message):
                        Text(message)
                    }
                }
            }
            .onChange(of: tripController.error) { error, _ in
                showingError = error != nil
            }
            .onAppear {
                print("FleetTripsView appeared")
                Task {
                    await tripController.refreshTrips()
                }
            }
        }
    }
    
    private func getTripCount(for filterIndex: Int) -> Int {
        switch filterIndex {
        case 0: // Current
            return currentTrips.count
        case 1: // Upcoming
            return upcomingTrips.count
        case 2: // Completed
            return completedTrips.count
        default:
            return 0
        }
    }
    
    private func getHeaderTitle() -> String {
        switch selectedFilter {
        case 0:
            return "Current Trips"
        case 1:
            return "Upcoming Trips"
        case 2:
            return "Completed Trips"
        default:
            return "All Trips"
        }
    }
}

// Update EmptyTripsView to show different messages based on filter
struct EmptyTripsView: View {
    let filterType: Int
    
    var emptyMessage: String {
        switch filterType {
        case 0:
            return "No trips currently in progress"
        case 1:
            return "No upcoming trips scheduled"
        case 2:
            return "No completed trips"
        default:
            return "No trips available"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray4))
            
            Text(emptyMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Add trips to manage your deliveries")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Trip card view
struct TripCardView: View {
    let trip: Trip
    @State private var showingAssignSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Trip header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                    
                    if !trip.eta.isEmpty {
                        Text("ETA: \(trip.eta)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                TripStatusBadge(status: trip.status)
            }
            .padding()
            
            Divider()
            
            // Trip route
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pickup")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.address)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                
                // Route line
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1)
                        .padding(.leading, 5.5)
                    
                    Spacer()
                }
                .frame(height: 20)
                
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dropoff")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.destination)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            // Show driver assignment section for all trips except completed ones
            if trip.status != .delivered {
                Divider()
                
                VStack(spacing: 12) {
                    // Vehicle Info if available
                    if trip.status != .pending {
                        let vehicleInfo = "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model) (\(trip.vehicleDetails.licensePlate))"
                        HStack(spacing: 24) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                Text(vehicleInfo)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Driver Assignment Button or Driver Info
                    if trip.driverId == nil {
                        Button(action: {
                            showingAssignSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Assign Driver")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    } else {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.green)
                            Text("Driver Assigned")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .sheet(isPresented: $showingAssignSheet) {
            AssignDriverView(trip: trip)
        }
    }
}

// Trip status badge
struct TripStatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    var displayText: String {
        switch status {
        case .pending: return "Unassigned"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .delivered: return "Completed"
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending: return Color(.systemGray5)
        case .assigned: return Color.blue.opacity(0.2)
        case .inProgress: return Color.orange.opacity(0.2)
        case .delivered: return Color.green.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch status {
        case .pending: return Color(.darkGray)
        case .assigned: return Color.blue
        case .inProgress: return Color.orange
        case .delivered: return Color.green
        }
    }
}

// Trip detail view
struct TripDetailView: View {
    @State private var showingAssignSheet = false
    
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Trip Status Card
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Trip Status")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TripStatusBadge(status: trip.status)
                        }
                        
                        Spacer()
                        
                        if !trip.eta.isEmpty {
                            Text(trip.eta)
                                .font(.subheadline)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                .padding(.horizontal)
                
                // Route Information Card
                VStack(alignment: .leading) {
                    Text("Trip Information")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent(label: "Trip Name", value: trip.name)
                            
                            Divider()
                            
                            LabeledContent(label: "Pickup", value: trip.address)
                            
                            Divider()
                            
                            LabeledContent(label: "Destination", value: trip.destination)
                            
                            if trip.status != .pending {
                                Divider()
                                let vehicleDisplayInfo = "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model) (\(trip.vehicleDetails.licensePlate))"
                                LabeledContent(label: "Vehicle", value: vehicleDisplayInfo)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                .padding(.horizontal)
                
                // Map Placeholder
                MapPlaceholder()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                
                // Action Button
                if trip.status == .pending {
                    Button(action: {
                        showingAssignSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Assign Driver & Vehicle")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAssignSheet) {
            // Show assign sheet here
            Text("Assign Trip")
        }
    }
}

// Map Placeholder
struct MapPlaceholder: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
            
            VStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                
                Text("Map View")
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }
}

// Labeled Content View
struct LabeledContent: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

// Driver Assignment View
struct AssignDriverView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var crewController = CrewDataController.shared
    let trip: Trip
    @State private var selectedDriverId: UUID?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                if crewController.drivers.isEmpty {
                    Text("No available drivers")
                        .foregroundColor(.gray)
                } else {
                    ForEach(crewController.drivers) { driver in
                        DriverRow(driver: driver, isSelected: selectedDriverId == driver.userID)
                            .onTapGesture {
                                selectedDriverId = driver.userID
                            }
                    }
                }
            }
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        assignDriver()
                    }
                    .disabled(selectedDriverId == nil || isLoading)
                }
            }
            .onAppear {
                crewController.update()
            }
        }
    }
    
    private func assignDriver() {
        guard let driverId = selectedDriverId else { return }
        isLoading = true
        
        Task {
            do {
                try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error assigning driver: \(error)")
            }
            isLoading = false
        }
    }
}

struct DriverRow: View {
    let driver: Driver
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(driver.name)
                    .font(.headline)
                Text(driver.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
} 
