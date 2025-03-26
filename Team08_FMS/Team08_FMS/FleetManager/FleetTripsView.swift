import SwiftUI
import CoreLocation
import MapKit

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    @State private var selectedFilter = 1 // Default to Upcoming
    @State private var showingAddTripView = false
    
    enum TabType: Int, CaseIterable {
        case current = 0
        case upcoming = 1
        case completed = 2
        
        var title: String {
            switch self {
            case .current: return "Current"
            case .upcoming: return "Upcoming"
            case .completed: return "Completed"
            }
        }
    }
    
    var currentTrips: [Trip] {
        tripController.getAllTrips().filter { $0.status == .inProgress }
    }
    
    var upcomingTrips: [Trip] {
        tripController.getAllTrips().filter { $0.status == .pending || $0.status == .assigned }
    }
    
    var completedTrips: [Trip] {
        let deliveredTrips = tripController.getAllTrips().filter { $0.status == .delivered }
        return !deliveredTrips.isEmpty ? deliveredTrips : tripController.recentDeliveries.compactMap { delivery in
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
        case 0: return currentTrips
        case 1: return upcomingTrips
        case 2: return completedTrips
        default: return []
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Trip Filter", selection: $selectedFilter) {
                    ForEach(TabType.allCases.map { $0.rawValue }, id: \.self) { index in
                        Text(TabType(rawValue: index)?.title ?? "")
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
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
                
                HStack {
                    Text(getHeaderTitle())
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddTripView = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Trip")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if filteredTrips.isEmpty {
                    EmptyTripsView(filterType: selectedFilter)
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
                Button("OK") { showingError = false }
            } message: {
                if let error = tripController.error {
                    switch error {
                    case .fetchError(let message),
                         .decodingError(let message),
                         .vehicleError(let message),
                         .updateError(let message),
                         .locationError(let message):
                        Text(message)
                    @unknown default:
                        Text("An unknown error occurred. Please try again later.")
                    }
                } else {
                    Text("An unexpected error occurred.")
                }
            }
            .onChange(of: tripController.error) { newError, _ in
                showingError = newError != nil
            }
            .onAppear {
                Task {
                    await tripController.refreshAllTrips()
                }
            }
            .sheet(isPresented: $showingAddTripView) {
                AddTripView { showingAddTripView = false }
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func getTripCount(for filterIndex: Int) -> Int {
        switch filterIndex {
        case 0: return currentTrips.count
        case 1: return upcomingTrips.count
        case 2: return completedTrips.count
        default: return 0
        }
    }
    
    private func getHeaderTitle() -> String {
        switch selectedFilter {
        case 0: return "Current Trips"
        case 1: return "Upcoming Trips"
        case 2: return "Completed Trips"
        default: return "All Trips"
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
enum ActiveSheet: Identifiable {
    case assign, detail
    
    var id: Int { hashValue }
}

struct TripCardView: View {
    let trip: Trip
    @State private var activeSheet: ActiveSheet? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Trip header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.headline)
                    
                    if !trip.eta.isEmpty {
                        Text("ETA: \(trip.eta)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Assignment badge
                if trip.driverId == nil && trip.status != .delivered {
                    Text("Unassigned")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                } else {
                    TripStatusBadge(status: trip.status)
                }
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
                        Text(trip.startingPoint.isEmpty ? trip.address : trip.startingPoint)
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
                
                HStack {
                    if trip.driverId == nil {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("Driver Unassigned")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(.green)
                        Text("Driver Assigned")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .contentShape(Rectangle()) // Ensures the entire card is tappable
        .onTapGesture {
            // If driver is unassigned, show assign sheet; otherwise, show detail sheet
            if trip.driverId == nil {
                activeSheet = .assign
            } else {
                activeSheet = .detail
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .assign:
                AssignDriverView(trip: trip)
            case .detail:
                TripDetailView(trip: trip)
            }
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
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    let trip: Trip

    var body: some View {
        NavigationView {
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
            .toolbar {
                // "Back" button similar to "Cancel" in AssignDriverView
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAssignSheet) {
                AssignDriverView(trip: trip)
            }
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
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    @State private var selectedDriverId: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
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
            .overlay {
                if isLoading {
                    ProgressView("Assigning driver...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func assignDriver() {
        guard let driverId = selectedDriverId else { return }
        isLoading = true
        
        Task {
            do {
                if trip.status == .pending {
                    // If trip is pending, we need to update the status to assigned
                    // In the database, use the raw enum value "assigned" for the trip_status field
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, status: "assigned")
                    // And separately update the driver assignment
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                } else {
                    // Otherwise, just update the driver
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                }
                
                // Refresh the trips to update the UI
                await tripController.refreshAllTrips()
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error assigning driver: \(error.localizedDescription)"
                    showingError = true
                }
                print("Error assigning driver: \(error)")
            }
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
