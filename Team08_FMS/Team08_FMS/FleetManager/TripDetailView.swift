import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var crewController = CrewDataController.shared
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    var trip: Trip
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    @State private var loading = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    
    // State variables
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedDriverId: UUID?
    @State private var showingDriverPicker = false
    
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
    
    private var statusColor: Color {
        switch trip.status {
        case .pending:
            return .orange
        case .assigned:
            return .blue
        case .inProgress:
            return .green
        case .delivered:
            return .purple
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
    
    private func calculateFuelCost(from distance: String) -> String {
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            let fuelCost = distance * 5.0
            return String(format: "$%.2f", fuelCost)
        }
        return "N/A"
    }
    
    private func calculateTotalRevenue(from distance: String) -> String {
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            let totalRevenue = distance * 11.1
            return String(format: "$%.2f", totalRevenue)
        }
        return "N/A"
    }
    
    private func getDriverName(for id: UUID?) -> String {
        if let driverId = id,
           let driver = crewController.drivers.first(where: { $0.userID == driverId }) {
            return driver.name
        }
        return "Unassigned"
    }
    
    // Computed property for driver assignment button visibility
    private var shouldShowAssignDriver: Bool {
        trip.status == .pending || trip.status == .assigned
    }
    
    // Computed property for trip timing
    private var tripTiming: String {
        if let startTime = trip.startTime, let endTime = trip.endTime {
            return "\(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        }
        return "Not scheduled"
    }
    
    // Computed property for trip costs
    private var tripCosts: (fuel: String, total: String) {
        let fuelCost = calculateFuelCost(from: trip.distance)
        let totalRevenue = calculateTotalRevenue(from: trip.distance)
        return (fuelCost, totalRevenue)
    }
    
    var body: some View {
        List {
            // TRIP INFORMATION Section
            Section {
                FleetTripRow(icon: "#", title: "Trip ID", value: trip.id.uuidString)
                FleetTripRow(icon: "ℹ️", title: "Destination", value: trip.destination)
                FleetTripRow(icon: "➤", title: "Address", value: trip.address)
                FleetTripRow(icon: "↔️", title: "Distance", value: trip.distance)
                
                if isEditing {
                    HStack {
                        Text("👤")
                            .frame(width: 26, alignment: .leading)
                        Text("Driver")
                            .foregroundColor(Color(UIColor.systemGray))
                            .font(.system(size: 17))
                        Spacer()
                        Menu {
                            Button("Unassign driver") {
                                selectedDriverId = nil
                            }
                            ForEach(crewController.drivers.filter { $0.status != .offDuty }, id: \.id) { driver in
                                Button(driver.name) {
                                    selectedDriverId = driver.userID
                                }
                            }
                        } label: {
                            Text(getDriverName(for: selectedDriverId))
                                .font(.system(size: 17))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, 1)
                } else {
                    FleetTripRow(icon: "👤", title: "Driver", value: getDriverName(for: trip.driverId))
                }
            } header: {
                Text("TRIP INFORMATION")
                    .textCase(nil)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
            
            // VEHICLE INFORMATION Section
            Section {
                FleetTripRow(icon: "🚗", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                FleetTripRow(icon: "#", title: "License Plate", value: trip.vehicleDetails.licensePlate)
            } header: {
                Text("VEHICLE INFORMATION")
                    .textCase(nil)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
            
            // DELIVERY STATUS Section
            Section {
                FleetTripRow(icon: "👤", title: "Status", value: trip.status.rawValue)
                FleetTripRow(icon: "⏰", title: "Pre-Trip Inspection", value: "Required")
                FleetTripRow(icon: "✓", title: "Post-Trip Inspection", value: "Required")
            } header: {
                Text("DELIVERY STATUS")
                    .textCase(nil)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
            
            // NOTES Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip Details")
                        .font(.system(size: 17, weight: .regular))
                        .padding(.bottom, 4)
                    
                    Group {
                        Text("Trip: \(trip.id.uuidString)")
                        Text("From: \(trip.address)")
                        Text("To: \(trip.destination)")
                        Text("Distance: \(trip.distance)")
                        if let driverId = selectedDriverId ?? trip.driverId {
                            Text("Driver: \(getDriverName(for: driverId))")
                        }
                        Text("Estimated Fuel Cost: \(calculateFuelCost(from: trip.distance))")
                        Text("Total Revenue: \(calculateTotalRevenue(from: trip.distance))")
                    }
                    .font(.system(size: 17))
                }
                .padding(.vertical, 8)
            } header: {
                Text("NOTES")
                    .textCase(nil)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
            
            // Delete Trip Button Section
            Section {
                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Trip")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Trip Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(isEditing ? "Cancel" : "Back") {
                    if isEditing {
                        isEditing = false
                        selectedDriverId = trip.driverId // Reset to original driver
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(.blue)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if trip.status == .pending || trip.status == .assigned {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                            selectedDriverId = trip.driverId // Initialize with current driver
                        }
                    }
                    .disabled(isEditing && !isFormValid)
                    .foregroundColor(.blue)
                }
            }
        }
        .alert("Delete Trip", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteTrip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
        .sheet(isPresented: $showingAssignSheet) {
            AssignDriverView(trip: trip)
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                if selectedDriverId != trip.driverId {
                    try await tripController.updateTripDriver(tripId: trip.id, driverId: selectedDriverId)
                }
                await MainActor.run {
                    isEditing = false
                }
            } catch {
                print("Error updating trip driver: \(error)")
            }
        }
    }
    
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
        
        selectedDriverId = trip.driverId
        
        // Reset touched states
        destinationEdited = false
        addressEdited = false
        notesEdited = false
    }
}

struct FleetTripRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(icon)
                .frame(width: 26, alignment: .leading)
            Text(title)
                .foregroundColor(Color(UIColor.systemGray))
                .font(.system(size: 17))
            Spacer()
            Text(value)
                .font(.system(size: 17))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 1)
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
