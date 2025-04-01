import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    var trip: Trip
    
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
    @State private var searchCompleterDelegate: FleetTripsSearchCompleterDelegate? = nil
    @State private var destinationSelected = false
    @State private var addressSelected = false
    
    // Touched states
    @State private var destinationEdited = false
    @State private var addressEdited = false
    @State private var notesEdited = false
    
    // Save operation state
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    // Additional pickup point state
    @State private var showingAddPickupSheet = false
    
    // Status related computed properties
    private var statusIcon: String {
        switch trip.status {
        case .pending:
            return "calendar"
        case .assigned:
            return "person.fill"
        case .inProgress:
            return "arrow.triangle.swap"
        case .delivered:
            return "checkmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .pending:
            return "Upcoming"
        case .assigned:
            return "Assigned"
        case .inProgress:
            return "In Progress"
        case .delivered:
            return "Delivered"
        }
    }
    
    // Location field enum
    enum LocationField {
        case destination, address, newPickup
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

    var body: some View {
        NavigationView {
            List {
                // Trip Information Section with driver assignment
                Section(header: Text("TRIP INFORMATION")) {
                    if isEditing {
                        // Editable Trip ID (non-editable)
                        HStack {
                            Text("Trip ID")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(trip.id.uuidString)
                        }
                        
                        // Editable Destination
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Destination", text: $editedDestination)
                                .onChange(of: editedDestination) { newValue in 
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
                            if destinationEdited && !isDestinationValid {
                                Text("Destination cannot be empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Editable Address
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Address", text: $editedAddress)
                                .onChange(of: editedAddress) { newValue in 
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
                            if addressEdited && !isAddressValid {
                                Text("Address cannot be empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Search Results if any - only show when appropriate based on selection state
                        if !searchResults.isEmpty && activeTextField != nil && 
                           ((activeTextField == .destination && !destinationSelected) || 
                            (activeTextField == .address && !addressSelected)) {
                            FleetTripsLocationSearchResults(results: searchResults) { result in
                                if activeTextField == .destination {
                                    destinationSelected = true
                                    searchForLocation(result.title, isDestination: true)
                                } else {
                                    addressSelected = true
                                    searchForLocation(result.title, isDestination: false)
                                }
                            }
                        }
                        
                        // Non-editable distance
                        if !calculatedDistance.isEmpty {
                            HStack {
                                Text("Distance")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(calculatedDistance)
                                    .foregroundColor(calculatedDistance != trip.distance ? .blue : .primary)
                            }
                        }
                        
                        // Driver assignment
                        HStack {
                            Text("Driver")
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            if let driverId = trip.driverId,
                               let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                                Text(driver.name)
                            } else {
                                Text("Unassigned")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        FleetTripDetailRow(icon: "number", title: "Trip ID", value: trip.id.uuidString)
                        FleetTripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                        FleetTripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
                        if !trip.distance.isEmpty {
                            FleetTripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                        }
                        
                        // Driver information
                        if let driverId = trip.driverId,
                           let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                            FleetTripDetailRow(icon: "person.fill", title: "Driver", value: driver.name)
                        } else {
                            FleetTripDetailRow(icon: "person.fill", title: "Driver", value: "Unassigned")
                        }
                    }
                }
                
                // Vehicle Information Section
                Section(header: Text("VEHICLE INFORMATION")) {
                    FleetTripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    FleetTripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                }
                
                // Additional Pickup Points Section (only show for non-delivered trips)
                if trip.status != .delivered {
                    tripPickupPoints
                }
                
                // Delivery Status Section
                Section(header: Text("DELIVERY STATUS")) {
                    FleetTripDetailRow(icon: statusIcon, title: "Status", value: statusText)
                    FleetTripDetailRow(
                        icon: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "clock.badge.checkmark.fill",
                        title: "Pre-Trip Inspection",
                        value: trip.hasCompletedPreTrip ? "Completed" : "Required"
                    )
                    FleetTripDetailRow(
                        icon: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "checkmark.shield.fill",
                        title: "Post-Trip Inspection",
                        value: trip.hasCompletedPostTrip ? "Completed" : "Required"
                    )
                }
                
                // Notes Section
                Section(header: Text("NOTES")) {
                    if isEditing {
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 100)
                            .onChange(of: editedNotes) { notesEdited = true }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if let notes = trip.notes {
                                Text("Trip Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trip: \(trip.id.uuidString)")
                                    Text("From: \(trip.address)")
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
                }
                
                // Add Assign Driver Button for unassigned trips only
                if trip.status == .pending && trip.driverId == nil {
                    Section {
                        Button(action: {
                            showingAssignSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Assign Driver")
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Delete section for upcoming trips
                if trip.status == .pending || trip.status == .assigned {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Trip")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeEditingFields()
                setupSearchCompleter()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if trip.status == .pending || trip.status == .assigned {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                if isFormValid {
                                    saveChanges()
                                }
                            } else {
                                initializeEditingFields()
                                isEditing.toggle()
                            }
                        }
                        .disabled(isEditing && !isFormValid)
                    }
                }
            }
            .alert("Delete Trip", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteTrip()
                }
            } message: {
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .alert("Changes Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Trip details have been updated successfully.")
            }
            .sheet(isPresented: $showingAssignSheet) {
                AssignDriverView(trip: trip)
            }
            .sheet(isPresented: $showingAddPickupSheet) {
                AddPickupPointView(tripId: trip.id) { newPickup in
                    addPickupPoint(newPickup: newPickup)
                }
            }
        }
    }
    
    // Pickup points section
    private var tripPickupPoints: some View {
        Section(header: Text("ADDITIONAL PICKUP POINTS")) {
            if trip.additionalPickups.isEmpty {
                Text("No additional pickup points")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(trip.additionalPickups) { pickup in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pickup.location)
                            .font(.headline)
                        Text(pickup.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if pickup.completed {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Completed")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        if !pickup.completed {
                            Button {
                                markPickupCompleted(pickup)
                            } label: {
                                Label("Complete", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                        
                        Button(role: .destructive) {
                            deletePickup(pickup)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            
            Button(action: {
                showingAddPickupSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add Pickup Point")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func markPickupCompleted(_ pickup: Trip) {
        Task {
            do {
                try await supabaseDataController.markPickupPointCompleted(pickupPointId: pickup.id)
                
                // Refresh the pickup points for this trip
                let updatedPickups = try await supabaseDataController.getPickupPointsForTrip(tripId: trip.id)
                await MainActor.run {
                    trip.additionalPickups = updatedPickups
                }
            } catch {
                print("Error marking pickup point as completed: \(error)")
            }
        }
    }
    
    private func deletePickup(_ pickup: Trip) {
        Task {
            do {
                try await supabaseDataController.deletePickupPoint(pickupPointId: pickup.id)
                
                // Refresh the pickup points for this trip
                let updatedPickups = try await supabaseDataController.getPickupPointsForTrip(tripId: trip.id)
                await MainActor.run {
                    trip.additionalPickups = updatedPickups
                }
            } catch {
                print("Error deleting pickup point: \(error)")
            }
        }
    }
    
    private func addPickupPoint(newPickup: Trip) {
        trip.additionalPickups.append(newPickup)
    }
    
    // Setup search completer
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = [.pointOfInterest, .address, .query]
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        let delegate = FleetTripsSearchCompleterDelegate { results in
            self.searchResults = results
        }
        searchCompleter.delegate = delegate
        searchCompleterDelegate = delegate
    }
    
    // Initialize editing fields with current trip values
    private func initializeEditingFields() {
        editedDestination = trip.destination
        editedAddress = trip.address
        
        if let notes = trip.notes {
            editedNotes = notes
        } else {
            editedNotes = ""
        }
        
        calculatedDistance = trip.distance
        selectedDriverId = trip.driverId
        
        // Reset touched states
        destinationEdited = false
        addressEdited = false
        notesEdited = false
    }
    
    // Search for location and update fields
    private func searchForLocation(_ query: String, isDestination: Bool) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        searchRequest.resultTypes = [.pointOfInterest, .address]
        
        MKLocalSearch(request: searchRequest).start { response, error in
            guard let response = response, error == nil,
                  let mapItem = response.mapItems.first else { return }
            
            if isDestination {
                self.editedDestination = mapItem.name ?? query
            } else {
                self.editedAddress = mapItem.name ?? query
                
                // Also set the address components if available
                let addressComponents = [
                    mapItem.placemark.thoroughfare,
                    mapItem.placemark.locality,
                    mapItem.placemark.administrativeArea,
                    mapItem.placemark.postalCode
                ].compactMap { $0 }.joined(separator: ", ")
                
                if !addressComponents.isEmpty {
                    self.editedAddress = addressComponents
                }
            }
            
            // Clear search results
            self.searchResults = []
        }
    }
    
    // Save changes to the trip
    private func saveChanges() {
        isSaving = true
        
        Task {
            do {
                let updatedTrip = try await supabaseDataController.updateTrip(
                    tripId: trip.id,
                    destination: editedDestination,
                    address: editedAddress,
                    notes: editedNotes,
                    driverId: selectedDriverId
                )
                
                if let updatedTrip = updatedTrip {
                    // Update trip with new values
                    await MainActor.run {
                        trip.destination = updatedTrip.destination
                        trip.address = updatedTrip.address
                        trip.notes = updatedTrip.notes
                        trip.driverId = updatedTrip.driverId
                        
                        // Update UI state
                        isSaving = false
                        isEditing = false
                        showingSaveSuccess = true
                    }
                } else {
                    throw NSError(domain: "TripError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to update trip"])
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Handle error (could show alert)
                    print("Error saving trip changes: \(error)")
                }
            }
        }
    }
    
    // Delete trip
    private func deleteTrip() {
        Task {
            do {
                try await tripController.deleteTrip(id: trip.id)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting trip: \(error)")
            }
        }
    }
}

// Common row element for trip details
struct FleetTripDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
        }
        .padding(.vertical, 2)
    }
}

// Search completer delegate class
class FleetTripsSearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
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

// Search results view
struct FleetTripsLocationSearchResults: View {
    let results: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(results, id: \.self) { result in
                    Button(action: {
                        onSelect(result)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.headline)
                            
                            Text(result.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.top, 4)
    }
} 
