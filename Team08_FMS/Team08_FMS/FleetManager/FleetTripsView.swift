import SwiftUI
import CoreLocation
import MapKit
import Foundation

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
                trip_status: TripStatus(rawValue: delivery.status) ?? .inProgress,
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
                estimated_time: nil,
                midPoint: "",
                midPointLat: 0,
                midPointLong: 0
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
                .font(.system(.headline, design: .default))
                .multilineTextAlignment(.center)
            
            Text("Add trips to manage your deliveries")
                .font(.system(.subheadline, design: .default))
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
    @State private var showingAddMidPoint = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status badge and mid-point button
            HStack {
                Text(statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
                
                // Add Mid-Point button for in-progress trips
                if trip.status == .inProgress {
                    Button(action: {
                        showingAddMidPoint = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add Mid-Point")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Rest of the card content
            Text(trip.displayName)
                .font(.headline)
            
            // Pickup location
            if let pickup = trip.pickup {
                HStack(spacing: 4) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text("From: \(pickup)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Mid-point if available
            if let midPoint = trip.middle_Pickup {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill.viewfinder")
                        .foregroundColor(.purple)
                        .font(.system(size: 14))
                    
                    Text("Via: \(midPoint)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Destination
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                
                Text("To: \(trip.destination)")
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
                        SupabaseDataController.shared.deleteTrip(tripID: trip.id)
                        try await TripDataController.shared.fetchAllTrips()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingDetails) {
            TripDetailView(trip: trip)
        }
        .sheet(isPresented: $showingAddMidPoint) {
            AddMidPointView(trip: trip)
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .pending: return "Unassigned"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .delivered: return "Completed"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .pending: return .gray
        case .assigned: return .blue
        case .inProgress: return .orange
        case .delivered: return .green
        }
    }
}

// Trip status badge
struct TripStatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(displayText)
            .font(.system(.subheadline, design: .default))
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

// Trip detail view
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    
    // Editing state variables
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    
    // Delivery receipt state
    @State private var showingDeliveryReceipt = false
    @State private var pdfData: Data? = nil
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    @State private var showingSignatureSheet = false
    @State private var fleetManagerSignature: Data? = nil
    
    // Location search state
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var activeTextField: LocationField? = nil
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: TripsSearchCompleterDelegate? = nil
    @State private var destinationSelected = false
    @State private var addressSelected = false
    
    // Touched states
    @State private var destinationEdited = false
    @State private var addressEdited = false
    @State private var notesEdited = false
    
    // Save operation state
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    // Location field enum
    enum LocationField {
        case destination, address
    }
    
    // Field validations
    private var isDestinationValid: Bool {
        let trimmed = editedDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    
    private var isAddressValid: Bool {
        let trimmed = editedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    
    // Overall form validation
    private var isFormValid: Bool {
        isDestinationValid && isAddressValid
    }
    
    // Helper to determine if search results should be shown
    private func shouldShowLocationResults() -> Bool {
        // First check if we have results and an active field
        guard !searchResults.isEmpty && activeTextField != nil else { 
            return false 
        }
        
        // Check destination field
        if activeTextField == .destination && !destinationSelected {
            return true
        }
        
        // Check address field
        if activeTextField == .address && !addressSelected {
            return true
        }
        
        return false
    }

    // MARK: - Helper Views
    
    @ViewBuilder
    private func tripIdRow() -> some View {
        HStack {
            Text("Trip ID")
                .foregroundColor(.secondary)
            Spacer()
            Text(trip.id.uuidString)
        }
    }
    
    @ViewBuilder
    private func destinationField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Destination", text: $editedDestination)
                .onChange(of: editedDestination) { _, newValue in 
                    handleDestinationChange(newValue)
                }
            if destinationEdited && !isDestinationValid {
                Text("Destination cannot be empty")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func addressField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Address", text: $editedAddress)
                .onChange(of: editedAddress) { _, newValue in 
                    handleAddressChange(newValue)
                }
            if addressEdited && !isAddressValid {
                Text("Address cannot be empty")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func locationSearchResults() -> some View {
        if shouldShowLocationResults() {
            TripsLocationSearchResults(results: searchResults) { result in
                if activeTextField == .destination {
                    destinationSelected = true
                    searchForLocation(result.title, isDestination: true)
                } else {
                    addressSelected = true
                    searchForLocation(result.title, isDestination: false)
                }
            }
        }
    }
    
    @ViewBuilder
    private func distanceInfo() -> some View {
        if !calculatedDistance.isEmpty {
            HStack {
                Text("Distance")
                    .foregroundColor(.secondary)
                Spacer()
                Text(calculatedDistance)
                    .foregroundColor(calculatedDistance != trip.distance ? .blue : .primary)
            }
        }
    }
    
    @ViewBuilder
    private func driverAssignment() -> some View {
        HStack {
            Text("Driver")
                .foregroundColor(.secondary)
            Spacer()
            
            Menu {
                // Option to unassign driver
                Button(action: {
                    selectedDriverId = nil
                }) {
                    HStack {
                        Text("Unassign driver")
                            .foregroundColor(.red)
                        Spacer()
                        if selectedDriverId == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
                
                // Available drivers
                ForEach(CrewDataController.shared.drivers.filter { $0.status == .available }, id: \.userID) { driver in
                    Button(action: {
                        selectedDriverId = driver.userID
                    }) {
                        HStack {
                            Text(driver.name)
                            Spacer()
                            if selectedDriverId == driver.userID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let driverId = selectedDriverId,
                       let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                        Text(driver.name)
                            .foregroundColor(.primary)
                    } else {
                        Text("Unassigned")
                            .foregroundColor(.gray)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                // Ensure crew data is updated when menu appears
                CrewDataController.shared.update()
            }
        }
    }
    
    @ViewBuilder
    private func editingView() -> some View {
        VStack {
            tripIdRow()
            destinationField()
            addressField()
            locationSearchResults()
            distanceInfo()
            driverAssignment()
        }
    }
    
    @ViewBuilder
    private func nonEditingView() -> some View {
        VStack {
            TripDetailRow(icon: "number", title: "Trip ID", value: trip.id.uuidString)
            
            // Show pickup location if available
            if let pickup = trip.pickup {
                TripDetailRow(icon: "location.circle.fill", title: "Pickup", value: pickup)
            }
            
            // Show mid-point if available
            if let midPoint = trip.middle_Pickup {
                TripDetailRow(icon: "location.fill.viewfinder", title: "Mid-Point", value: midPoint)
            }
            
            TripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
            TripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
            
            if !trip.distance.isEmpty {
                TripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
            }
            
            // Driver information
            if let driverId = trip.driverId,
                let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                TripDetailRow(icon: "person.fill", title: "Driver", value: driver.name)
            } else {
                TripDetailRow(icon: "person.fill", title: "Driver", value: "Unassigned")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Trip Information Section with driver assignment
                Section {
                    if isEditing {
                        editingView()
                    } else {
                        nonEditingView()
                    }
                } header: {
                    Text("TRIP INFORMATION")
                }
                
                // Vehicle Information Section
                Section {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                } header: {
                    Text("VEHICLE INFORMATION")
                }
                
                // Delivery Status Section
                Section {
                    TripDetailRow(icon: statusIcon, title: "Status", value: statusText)
                    TripDetailRow(
                        icon: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "clock.badge.checkmark.fill",
                        title: "Pre-Trip Inspection",
                        value: trip.hasCompletedPreTrip ? "Completed" : "Required"
                    )
                    TripDetailRow(
                        icon: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "checkmark.shield.fill",
                        title: "Post-Trip Inspection",
                        value: trip.hasCompletedPostTrip ? "Completed" : "Required"
                    )
                } header: {
                    Text("DELIVERY STATUS")
                }
                
                // Added Pickup Section
                Section {
                    if let middlePickup = trip.middle_Pickup, !middlePickup.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill.viewfinder")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                Text(middlePickup)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            if let lat = trip.middle_pickup_latitude, 
                               let long = trip.middle_pickup_longitude {
                                Text("Coordinates: \(String(format: "%.5f", lat)), \(String(format: "%.5f", long))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("N/A")
                            .foregroundColor(.gray)
                            .italic()
                    }
                } header: {
                    Text("ADDED PICKUP")
                }
                
                // Notes Section
                Section {
                    if isEditing {
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 100)
                            .onChange(of: editedNotes) { _, _ in notesEdited = true }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if trip.notes != nil {
                                Text("Trip Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trip: \(trip.id.uuidString)")
                                    
                                    // Show pickup location in notes section if available
                                    if let pickup = trip.pickup {
                                        Text("From: \(pickup)")
                                    } else {
                                        Text("From: \(trip.address)")
                                    }
                                    
                                    // Show mid-point location in notes section if available
                                    if let midPoint = trip.middle_Pickup {
                                        Text("Mid-Point: \(midPoint)")
                                    }
                                    
                                    Text("To: \(trip.destination)")
                                    
                                    if !trip.distance.isEmpty {
                                        Text("Distance: \(trip.distance)")
                                    }
                                    
                                    // Display driver information if available
                                    if let driverId = trip.driverId,
                                       let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                                        Text("Driver: \(driver.name)")
                                    } else {
                                        Text("Driver: Unassigned")
                                    }
                                    
                                    let (fuelCostString, fuelCostValue) = calculateFuelCost(from: trip.distance)
                                    Text("Estimated Fuel Cost: \(fuelCostString)")
                                    Text("Total Revenue: \(calculateTotalRevenue(distance: trip.distance, fuelCost: fuelCostValue))")
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("NOTES")
                }
                
                // Add Assign Driver Button for unassigned trips only
                if trip.status == .pending && trip.driverId == nil {
                    Section {
                        Button(action: {
                            showingAssignSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.fill.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Assign Driver")
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } header: {
                        Text("Driver Assignment")
                    }
                }
                
                // Add Delete Button for admins - placed at bottom for safety
                Section {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Trip")
                                .bold()
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } header: {
                    Text("Danger Zone")
                }
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(
                        title: Text("Delete Trip"),
                        message: Text("Are you sure you want to delete this trip? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            Task {
                                do {
                                    try await tripController.deleteTrip(id: trip.id)
                                    dismiss()
                                } catch {
                                    print("Error deleting trip: \(error)")
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Edit/Save button
                    if isEditing {
                        Button(action: {
                            Task {
                                await save()
                            }
                        }) {
                            Text("Save")
                                .bold()
                                .opacity(isSaving ? 0.5 : 1.0)
                        }
                        .disabled(isSaving || !isFormValid)
                    } else {
                        Button(action: {
                            startEditing()
                        }) {
                            Text("Edit")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button(action: {
                            cancelEditing()
                        }) {
                            Text("Cancel")
                        }
                    }
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // Setup initial state when view appears
    private func setupInitialState() {
        editedDestination = trip.destination
        editedAddress = trip.address
        editedNotes = trip.notes ?? ""
        selectedDriverId = trip.driverId
        
        // Setup search completer delegate
        searchCompleterDelegate = TripsSearchCompleterDelegate(onUpdate: { results in
            self.searchResults = results
        })
        searchCompleter.delegate = searchCompleterDelegate
        searchCompleter.resultTypes = .address
        
        // Refresh trip data to ensure we have the latest middle pickup info
        Task {
            await tripController.refreshAllTrips()
        }
    }
    
    // Start editing mode
    private func startEditing() {
        isEditing = true
    }
    
    // Cancel editing and reset form
    private func cancelEditing() {
        isEditing = false
        
        // Reset form values
        editedDestination = trip.destination
        editedAddress = trip.address
        editedNotes = trip.notes ?? ""
        
        // Reset validation flags
        destinationEdited = false
        addressEdited = false
        notesEdited = false
        
        // Reset selection state
        destinationSelected = false
        addressSelected = false
        
        // Clear search
        searchResults = []
        activeTextField = nil
    }
    
    // Save trip updates
    private func save() async {
        isSaving = true
        
        // Update trip with edited values
        do {
            // Update main trip details
            try await SupabaseDataController.shared.updateTripDetails(
                id: trip.id,
                destination: editedDestination,
                address: editedAddress,
                notes: editedNotes,
                distance: calculatedDistance.isEmpty ? nil : calculatedDistance,
                time: calculatedTime.isEmpty ? nil : calculatedTime
            )
            
            // If driver is selected, update driver assignment
            if let driverId = selectedDriverId {
                try await SupabaseDataController.shared.updateTrip(
                    id: trip.id,
                    driverId: driverId
                )
            }
            
            // Refresh data
            await tripController.refreshAllTrips()
            
            // Show success briefly
            showingSaveSuccess = true
            
            // Reset state
            isEditing = false
            isSaving = false
            
            // Reset edited flags
            destinationEdited = false
            addressEdited = false
            notesEdited = false
        } catch {
            print("Error saving trip: \(error)")
            isSaving = false
        }
    }
    
    // Handle location search selection
    private func searchForLocation(_ locationName: String, isDestination: Bool) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = locationName
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response else {
                print("Error searching for location: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let firstItem = response.mapItems.first {
                let coordinate = firstItem.placemark.coordinate
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                // Get full address
                CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                    guard let placemark = placemarks?.first, error == nil else {
                        print("Reverse geocoding failed: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    let address = formatAddress(from: placemark)
                    
                    if isDestination {
                        // Update destination
                        editedDestination = locationName
                        
                        // Calculate distance if we have both origin and destination
                        if !editedAddress.isEmpty {
                            calculateRouteDistance()
                        }
                    } else {
                        // Update address
                        editedAddress = address
                        
                        // Calculate distance if we have both origin and destination
                        if !editedDestination.isEmpty {
                            calculateRouteDistance()
                        }
                    }
                }
            }
        }
    }
    
    // Format address from placemark
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components = [String]()
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    // Calculate distance between two locations
    private func calculateRouteDistance() {
        // Create geocoding requests for both addresses
        let geocoder = CLGeocoder()
        
        // First, geocode the starting address
        geocoder.geocodeAddressString(editedAddress) { startPlacemarks, startError in
            guard let startPlacemark = startPlacemarks?.first,
                  let startLocation = startPlacemark.location else {
                print("Start location geocoding failed: \(startError?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Then, geocode the destination address
            geocoder.geocodeAddressString(editedDestination) { destPlacemarks, destError in
                guard let destPlacemark = destPlacemarks?.first,
                      let destLocation = destPlacemark.location else {
                    print("Destination location geocoding failed: \(destError?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Calculate distance
                let distance = startLocation.distance(from: destLocation)
                let distanceInMiles = distance / 1609.344 // Convert meters to miles
                
                // Format distance string
                calculatedDistance = String(format: "%.2f miles", distanceInMiles)
                
                // Roughly estimate travel time (assuming avg speed of 45 mph)
                let timeInHours = distanceInMiles / 45
                let hours = Int(timeInHours)
                let minutes = Int((timeInHours - Double(hours)) * 60)
                
                if hours > 0 {
                    calculatedTime = "\(hours)h \(minutes)m"
                } else {
                    calculatedTime = "\(minutes)m"
                }
            }
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .pending: return "Unassigned"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .delivered: return "Completed"
        }
    }
    
    private var statusIcon: String {
        switch trip.status {
        case .pending: return "clock"
        case .assigned: return "person.fill.checkmark"
        case .inProgress: return "arrow.triangle.turn.up.right.circle.fill"
        case .delivered: return "checkmark.circle.fill"
        }
    }
    
    private func calculateFuelCost(from distance: String) -> (String, Double) {
        // Extract numeric value from distance string
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            // Calculate fuel cost ($0.5 per km/mile)
            let fuelCost = distance * 0.5
            return (String(format: "$%.2f", fuelCost), fuelCost)
        }
        return ("N/A", 0.0)
    }
    
    private func calculateTotalRevenue(distance: String, fuelCost: Double) -> String {
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            // Total Revenue = Fuel Cost + ($0.25 × Distance) + $50
            let distanceRevenue = distance * 0.25
            let totalRevenue = fuelCost + distanceRevenue + 50.0
            return String(format: "$%.2f", totalRevenue)
        }
        return "N/A"
    }
    
    private func handleDestinationChange(_ newValue: String) {
        destinationEdited = true
        
        // If destination was previously selected and user is editing
        if destinationSelected && !newValue.isEmpty {
            if newValue != editedDestination {
                destinationSelected = false
            }
        }
        
        // Only show search results if not already selected and query has 3+ chars
        if !destinationSelected && newValue.count > 2 {
            searchCompleter.queryFragment = newValue
            activeTextField = .destination
        } else {
            searchResults = []
        }
    }
    
    private func handleAddressChange(_ newValue: String) {
        addressEdited = true
        
        // If address was previously selected and user is editing
        if addressSelected && !newValue.isEmpty {
            if newValue != editedAddress {
                addressSelected = false
            }
        }
        
        // Only show search results if not already selected and query has 3+ chars
        if !addressSelected && newValue.count > 2 {
            searchCompleter.queryFragment = newValue
            activeTextField = .address
        } else {
            searchResults = []
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

// Location search results view
struct TripsLocationSearchResults: View {
    let results: [MKLocalSearchCompletion]
    let onResultSelected: (MKLocalSearchCompletion) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(results, id: \.self) { result in
                    Button(action: {
                        onResultSelected(result)
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            // Map pin icon with different colors for different types of locations
                            Image(systemName: iconForResult(result))
                                .foregroundColor(colorForResult(result))
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                
                                // Display the type of location
                                if let locationType = getLocationType(result) {
                                    Text(locationType)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        .frame(height: min(CGFloat(results.count * 70), 280))
    }
    
    // Helper function to determine icon based on result type
    private func iconForResult(_ result: MKLocalSearchCompletion) -> String {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return "fork.knife"
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return "bed.double.fill"
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return "cross.fill"
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return "book.fill"
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return "leaf.fill"
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return "bag.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    // Helper function to determine color based on result type
    private func colorForResult(_ result: MKLocalSearchCompletion) -> Color {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return .orange
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return .blue
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return .red
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return .green
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return .green
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return .purple
        } else {
            return .red
        }
    }
    
    // Helper function to get location type
    private func getLocationType(_ result: MKLocalSearchCompletion) -> String? {
        let subtitle = result.subtitle.lowercased()
        
        if subtitle.contains("restaurant") || subtitle.contains("café") || subtitle.contains("cafe") {
            return "Restaurant"
        } else if subtitle.contains("hotel") || subtitle.contains("resort") {
            return "Hotel"
        } else if subtitle.contains("hospital") || subtitle.contains("clinic") {
            return "Healthcare"
        } else if subtitle.contains("school") || subtitle.contains("college") || subtitle.contains("university") {
            return "Education"
        } else if subtitle.contains("park") || subtitle.contains("garden") {
            return "Park"
        } else if subtitle.contains("mall") || subtitle.contains("shop") || subtitle.contains("store") {
            return "Shopping"
        } else if subtitle.contains("airport") || subtitle.contains("station") {
            return "Transport"
        } else if subtitle.contains("street") || subtitle.contains("road") {
            return "Street"
        } else if subtitle.contains("city") || subtitle.contains("town") {
            return "City"
        } else if subtitle.contains("landmark") || subtitle.contains("monument") {
            return "Landmark"
        } else {
            return nil
        }
    }
}

// Search completer delegate for location autocompletion
class TripsSearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onResultsUpdated: (([MKLocalSearchCompletion]) -> Void)?
    
    override init() {
        super.init()
    }
    
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onResultsUpdated = onUpdate
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResultsUpdated?(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// Add SignatureCaptureView
struct SignatureCaptureView: View {
    @Binding var signature: Data?
    @State private var currentDrawing: Path = Path()
    @State private var drawings: [Path] = []
    @GestureState private var isDrawing: Bool = false
    
    var body: some View {
        VStack {
            Text("Please sign below")
                .font(.headline)
                .padding()
            
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray, width: 1)
                    .frame(height: 200)
                
                Path { path in
                    path.addPath(currentDrawing)
                    drawings.forEach { path.addPath($0) }
                }
                .stroke(Color.black, lineWidth: 2)
                .background(Color.white)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = value.location
                            if isDrawing {
                                currentDrawing.addLine(to: point)
                            } else {
                                currentDrawing = Path()
                                currentDrawing.move(to: point)
                            }
                        }
                        .onEnded { _ in
                            drawings.append(currentDrawing)
                            currentDrawing = Path()
                            
                            // Convert drawing to image and then to Data
                            let renderer = ImageRenderer(content: Path { path in
                                drawings.forEach { path.addPath($0) }
                            }.stroke(Color.black, lineWidth: 2))
                            
                            if let uiImage = renderer.uiImage {
                                signature = uiImage.pngData()
                            }
                        }
                        .updating($isDrawing) { (value, state, transaction) in
                            state = true
                        }
                )
            }
            .padding()
            
            Button(action: {
                currentDrawing = Path()
                drawings = []
                signature = nil
            }) {
                Text("Clear")
                    .foregroundColor(.red)
            }
            .padding()
        }
    }
}

// Add Mid-Point View
struct AddMidPointView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var midPointLocation: String
    @State private var midPointCoordinate: CLLocationCoordinate2D?
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: SearchCompleterDelegate?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isEditing = false
    
    init(trip: Trip) {
        self.trip = trip
        // Initialize with existing mid-point if available
        _midPointLocation = State(initialValue: trip.middle_Pickup ?? "")
        
        // Set coordinates if they exist
        if let lat = trip.middle_pickup_latitude, let lon = trip.middle_pickup_longitude {
            _midPointCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            _isEditing = State(initialValue: true)
        } else {
            _midPointCoordinate = State(initialValue: nil)
            _isEditing = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Current mid-point information (if editing)
                if isEditing {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("You're editing the existing mid-point")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Location Search Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mid-Point Location")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                        
                        TextField("Enter mid-point location", text: $midPointLocation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: midPointLocation) { _, newValue in
                                if !newValue.isEmpty {
                                    searchCompleter.queryFragment = newValue
                                } else {
                                    searchResults = []
                                }
                            }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { result in
                                    Button(action: {
                                        midPointLocation = result.title
                                        searchResults = []
                                        let searchRequest = MKLocalSearch.Request(completion: result)
                                        let search = MKLocalSearch(request: searchRequest)
                                        search.start { response, error in
                                            if let coordinate = response?.mapItems.first?.placemark.coordinate {
                                                midPointCoordinate = coordinate
                                            }
                                        }
                                    }) {
                                        VStack(alignment: .leading) {
                                            Text(result.title)
                                                .font(.headline)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Divider()
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                        }
                        .frame(height: 200)
                    }
                }
                
                Spacer()
                
                Button(action: saveMidPoint) {
                    HStack {
                        Text(isEditing ? "Update Mid-Point" : "Add Mid-Point")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(midPointCoordinate != nil ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(midPointCoordinate == nil)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle(isEditing ? "Edit Mid-Point" : "Add Mid-Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                setupSearchCompleter()
            }
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = [.pointOfInterest, .address, .query]
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        let delegate = SearchCompleterDelegate { results in
            self.searchResults = Array(results.prefix(10))
        }
        searchCompleter.delegate = delegate
        searchCompleterDelegate = delegate
    }
    
    private func saveMidPoint() {
        guard let coordinate = midPointCoordinate else { return }
        
        Task {
            do {
                let success = try await SupabaseDataController.shared.updateTripMidPoint(
                    tripId: trip.id,
                    midPoint: midPointLocation,
                    midPointLatitude: coordinate.latitude,
                    midPointLongitude: coordinate.longitude
                )
                
                if success {
                    await MainActor.run {
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        showingAlert = true
                        alertMessage = "Failed to add mid-point. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    showingAlert = true
                    alertMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

