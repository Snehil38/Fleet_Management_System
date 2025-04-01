import SwiftUI
import MapKit
import CoreLocation
import Foundation
import Combine

// Import necessary models and controllers
import Supabase

// Custom null value that conforms to Encodable
struct EncodableNull: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    @State private var selectedFilter = 1 // Default to Upcoming
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    // Define tab types
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
        // Get all trips with in-progress status
        return tripController.getAllTrips().filter { $0.status == .inProgress }
    }
    
    var upcomingTrips: [Trip] {
        // Get all trips with pending or assigned status
        return tripController.getAllTrips().filter { $0.status == .pending || $0.status == .assigned }
    }
    
    var completedTrips: [Trip] {
        // Get all completed trips - either from recentDeliveries or directly from trips
        let deliveredTrips = tripController.getAllTrips().filter { $0.status == .delivered }
        
        if !deliveredTrips.isEmpty {
            return deliveredTrips
        }
        
        // Fallback to recentDeliveries if needed
        return tripController.recentDeliveries.compactMap { delivery in
            // Create a mock vehicle for the delivery
            let vehicle = Vehicle.mockVehicle(licensePlate: delivery.vehicle)
            
            // Create a SupabaseTrip with the delivery information
            let supabaseTrip = SupabaseTrip(
                id: delivery.id,
                destination: delivery.location,
                trip_status: "delivered",
                has_completed_pre_trip: true,
                has_completed_post_trip: true,
                vehicle_id: vehicle.id,
                driver_id: nil, secondary_driver_id: nil,
                start_time: nil,
                end_time: nil,
                notes: delivery.notes,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                start_latitude: 0,
                start_longitude: 0,
                end_latitude: 0,
                end_longitude: 0,
                pickup: delivery.location,
                estimated_distance: nil,
                estimated_time: nil
            )
            
            return Trip(from: supabaseTrip, vehicle: vehicle)
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
            VStack(spacing: 0) {
                // Filter control with counts
                Picker("Trip Filter", selection: $selectedFilter) {
                    ForEach(TabType.allCases.map { $0.rawValue }, id: \.self) { index in
                        Text("\(TabType(rawValue: index)?.title ?? "") (\(getTripCount(for: index)))")
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Simple header section
                HStack {
                    Text(getHeaderTitle())
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Trip list
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
                Button("OK") {
                    showingError = false
                }
            } message: {
                if let error = tripController.error {
                    switch error {
                    case .fetchError(let message),
                         .decodingError(let message),
                         .vehicleError(let message),
                         .updateError(let message),
                         .locationError(let message):
                        Text(message)
                    }
                }
            }
            .onChange(of: tripController.error) { error, _ in
                showingError = error != nil
            }
//            .onAppear {
//                Task {
//                    await tripController.refreshAllTrips()
//                }
//            }
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
enum ActiveSheet: Identifiable {
    case assign, detail
    
    var id: Int { hashValue }
}

struct TripCardView: View {
    let trip: Trip
    @State private var showingDetails = false
    @StateObject private var crewController = CrewDataController.shared
    @State var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status badge only (removed ETA)
            HStack {
                Text(statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
            }
            
            // Trip name
            Text(trip.displayName)
                .font(.headline)
            
            // Destination
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Distance if available
            if !trip.distance.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "ruler.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text(trip.distance)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Bottom section with vehicle info and driver name
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vehicle:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(trip.vehicleDetails.name)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Driver information
                if let driverId = trip.driverId,
                   let driver = crewController.drivers.first(where: { $0.userID == driverId }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Driver:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(driver.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Unassigned")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onTapGesture {
            showingDetails = true
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Alert"),
                message: Text("Are you sure you want to delete this trip?"),
                primaryButton: .destructive(Text("Yes")) {
                    Task {
                        try? await TripDataController.shared.deleteTrip(id: trip.id)
                        try await TripDataController.shared.fetchAllTrips()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingDetails) {
            TripDetailView(trip: trip)
        }
        .contextMenu {
            if trip.status == .pending || trip.status == .assigned || trip.status == .delivered {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Trip", systemImage: "trash")
                }
            }
        }
        .onAppear {
            crewController.update()
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return "Initiated"
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return "Pre-Trip Completed"
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return "Post-Trip Completed"
            }
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Delivered"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return .orange // Initiated
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return .blue // Pre-Trip Completed
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return .green // Post-Trip Completed
            }
            return .blue // In Progress
        case .pending:
            return .green
        case .delivered:
            return .gray
        case .assigned:
            return .yellow
        }
    }
}

// Trip status badge
struct TripStatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
        case .assigned: return Color.blue.opacity(0.15)
        case .inProgress: return Color.orange.opacity(0.15)
        case .delivered: return Color.green.opacity(0.15)
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
    // Remove or keep crewController if needed for other purposes.
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    
    @State private var selectedDriverId: UUID?
    @State private var selectedSecondDriverId: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // Fetched available drivers for the trip duration.
    @State private var fetchedAvailableDrivers: [Driver] = []
    
    // If the trip distance is greater than 500, it's considered a long trip.
    private var isLongTrip: Bool {
        // Extract numeric value from distance string
        let numericDistance = trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        if let distance = Double(numericDistance) {
            return distance > 500
        }
        return false
    }
    
    // Use the fetched drivers instead of the crewController drivers.
    private var availableDrivers: [Driver] {
        return fetchedAvailableDrivers
    }
    
    // Exclude the driver already selected as primary.
    private var availableSecondDrivers: [Driver] {
        if let firstDriverId = selectedDriverId {
            return availableDrivers.filter { $0.userID != firstDriverId }
        }
        return availableDrivers
    }
    
    var body: some View {
        NavigationView {
            List {
                if availableDrivers.isEmpty {
                    Text("No available drivers")
                        .foregroundColor(.gray)
                } else {
                    // First Driver Section
                    Section(header: Text(isLongTrip ? "PRIMARY DRIVER" : "DRIVER")) {
                        ForEach(availableDrivers) { driver in
                            DriverRow(driver: driver, isSelected: selectedDriverId == driver.userID)
                                .onTapGesture {
                                    selectedDriverId = driver.userID
                                    // If the second driver is the same as the first, deselect it
                                    if selectedSecondDriverId == driver.userID {
                                        selectedSecondDriverId = nil
                                    }
                                }
                        }
                    }
                    
                    // Second Driver Section (only for long trips)
                    if isLongTrip {
                        Section(header: Text("SECONDARY DRIVER (Required for trips > 500km)")) {
                            ForEach(availableSecondDrivers) { driver in
                                DriverRow(driver: driver, isSelected: selectedSecondDriverId == driver.userID)
                                    .onTapGesture {
                                        selectedSecondDriverId = driver.userID
                                    }
                            }
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
                    .disabled(!canAssign)
                }
            }
            .onAppear {
                fetchAvailableDrivers()
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
    
    private var canAssign: Bool {
        if isLoading { return false }
        if isLongTrip {
            return selectedDriverId != nil && selectedSecondDriverId != nil
        }
        return selectedDriverId != nil
    }
    
    private func fetchAvailableDrivers() {
        // Use trip.startTime and trip.endTime if available.
        Task {
            do {
                let drivers = try await SupabaseDataController.shared.fetchAvailableDrivers(
                    startDate: trip.startTime!,
                    endDate: trip.endTime!
                )
                await MainActor.run {
                    self.fetchedAvailableDrivers = drivers
                }
            } catch {
                print("Error fetching available drivers: \(error)")
            }
        }
    }
    
    private func assignDriver() {
        guard let driverId = selectedDriverId else { return }
        isLoading = true
        
        Task {
            do {
                if trip.status == .pending {
                    // Update trip status to assigned
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, status: "assigned")
                    
                    // Update primary driver
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                    
                    // If it's a long trip, update secondary driver
                    if isLongTrip, let secondDriverId = selectedSecondDriverId {
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, secondaryDriverId: secondDriverId)
                    }
                } else {
                    // Just update the driver assignments
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                    if isLongTrip, let secondDriverId = selectedSecondDriverId {
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, secondaryDriverId: secondDriverId)
                    }
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
                    .fontWeight(.medium)
                Text(driver.email)
                    .font(.caption)
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

// New view for adding a pickup point
struct AddPickupPointView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    
    let tripId: UUID
    let onAdd: (Trip) -> Void
    
    @State private var location = ""
    @State private var address = ""
    @State private var showingSearchResults = false
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isLoading = false
    
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: AddPickupCompleterDelegate?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PICKUP DETAILS")) {
                    TextField("Location Name", text: $location)
                        .onChange(of: location) { newValue in
                            if newValue.count > 2 {
                                searchCompleter.queryFragment = newValue
                                showingSearchResults = true
                            } else {
                                showingSearchResults = false
                            }
                        }
                    
                    if showingSearchResults && !searchResults.isEmpty {
                        List {
                            ForEach(searchResults, id: \.self) { result in
                                Button(action: {
                                    searchForLocation(result.title)
                                    location = result.title
                                    showingSearchResults = false
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.title)
                                            .font(.headline)
                                        Text(result.subtitle)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .frame(height: min(300, CGFloat(searchResults.count * 60)))
                    }
                    
                    TextField("Address", text: $address)
                }
                
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Adding pickup point...")
                            Spacer()
                        }
                    }
                } else {
                    Section {
                        Button(action: addPickupPoint) {
                            HStack {
                                Spacer()
                                Text("Add Pickup Point")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(location.isEmpty || address.isEmpty || coordinate == nil)
                    }
                }
            }
            .navigationTitle("Add Pickup Point")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupSearchCompleter()
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = .address
        let delegate = AddPickupCompleterDelegate { results in
            self.searchResults = results
        }
        searchCompleter.delegate = delegate
        self.searchCompleterDelegate = delegate
    }
    
    private func searchForLocation(_ query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, error == nil else {
                print("Error searching for location: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let firstItem = response.mapItems.first {
                let addressComponents = [
                    firstItem.placemark.thoroughfare,
                    firstItem.placemark.locality,
                    firstItem.placemark.administrativeArea,
                    firstItem.placemark.postalCode,
                    firstItem.placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                
                address = addressComponents
                coordinate = firstItem.placemark.coordinate
            }
        }
    }
    
    private func addPickupPoint() {
        guard let coordinate = coordinate else { return }
        
        isLoading = true
        
        Task {
            do {
                // Add the pickup point to the database
                try await supabaseDataController.addPickupPointToTrip(
                    tripId: tripId,
                    location: location,
                    address: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                
                // Get the newly created pickup point
                let pickupPoints = try await supabaseDataController.getPickupPointsForTrip(tripId: tripId)
                if let newPickup = pickupPoints.last {
                    await MainActor.run {
                        onAdd(newPickup)
                        isLoading = false
                        dismiss()
                    }
                } else {
                    // If we couldn't find the pickup point in the database, create it locally
                    let newPickup = Trip.createPickupPoint(
                        id: UUID(),
                        parentTripId: tripId,
                        location: location,
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        sequence: 1,
                        completed: false
                    )
                    await MainActor.run {
                        onAdd(newPickup)
                        isLoading = false
                        dismiss()
                    }
                }
            } catch {
                print("Error adding pickup point: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// Class-based delegate for AddPickupPointView
class AddPickupCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: ([MKLocalSearchCompletion]) -> Void
    
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
} 


