import SwiftUI
import CoreLocation
import MapKit

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    @State private var selectedFilter = 1 // Default to Upcoming
    
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
                         .updateError(let message):
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
            Text(trip.name)
                .font(.title3)
                .fontWeight(.semibold)
            
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
                    Text(trip.vehicleDetails.licensePlate)
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
        .sheet(isPresented: $showingDetails) {
            TripDetailView(trip: trip)
        }
        .onAppear {
            crewController.update()
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Completed"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .inProgress:
            return .blue
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

// Trip detail view
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    let trip: Trip
    
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
                // Trip Information Section
                Section(header: Text("TRIP INFORMATION")) {
                    TripDetailRow(icon: "number", title: "Trip ID", value: trip.name)
                    TripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                    TripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
                    if !trip.distance.isEmpty {
                        TripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                    }
                }
                
                // Vehicle Information Section
                Section(header: Text("VEHICLE INFORMATION")) {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                }
                
                // Delivery Status Section
                Section(header: Text("DELIVERY STATUS")) {
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
                }
                
                // Proof of Delivery Section (for completed trips)
                if trip.status == .delivered {
                    Section(header: Text("PROOF OF DELIVERY")) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Delivery Receipt")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "signature")
                                    .foregroundColor(.blue)
                                Text("Customer Signature")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Notes Section
                Section(header: Text("NOTES")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let notes = trip.notes {
                            Text("Trip: \(trip.name)")
                            Text("From: \(trip.startingPoint)")
                            Text("Cargo Type: General Goods")
                            Text("Distance: \(trip.distance)")
                            let (fuelCostString, fuelCostValue) = calculateFuelCost(from: trip.distance)
                            Text("Estimated Fuel Cost: \(fuelCostString)")
                            Text("Total Revenue: \(calculateTotalRevenue(distance: trip.distance, fuelCost: fuelCostValue))")
                        }
                    }
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
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
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAssignSheet) {
                AssignDriverView(trip: trip)
            }
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Completed"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusIcon: String {
        switch trip.status {
        case .inProgress:
            return "car.circle.fill"
        case .pending:
            return "clock.fill"
        case .delivered:
            return "checkmark.circle.fill"
        case .assigned:
            return "person.fill"
        }
    }
}

//struct TripDetailRow: View {
//    let icon: String
//    let title: String
//    let value: String
//    
//    var body: some View {
//        HStack {
//            Image(systemName: icon)
//                .foregroundColor(.blue)
//                .frame(width: 24)
//            
//            Text(title)
//                .foregroundColor(.gray)
//            
//            Spacer()
//            
//            Text(value)
//                .foregroundColor(.primary)
//        }
//    }
//}

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
    @State private var selectedSecondDriverId: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    private var isLongTrip: Bool {
        // Extract numeric value from distance string
        let numericDistance = trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            return distance > 500
        }
        return false
    }
    
    private var availableDrivers: [Driver] {
        // Filter out drivers who are not available
        return crewController.drivers.filter { $0.status == .available }
    }
    
    private var availableSecondDrivers: [Driver] {
        // Filter out the first selected driver from the list of available drivers
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
    
    private var canAssign: Bool {
        if isLoading { return false }
        if isLongTrip {
            return selectedDriverId != nil && selectedSecondDriverId != nil
        }
        return selectedDriverId != nil
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

