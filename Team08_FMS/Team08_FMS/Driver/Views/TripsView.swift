import SwiftUI
import CoreLocation

struct TripsView: View {
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var selectedFilter: TripFilter = .all
    @State private var showingError = false
    
    enum TripFilter {
        case all, current, upcoming, delivered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                Text("All").tag(TripFilter.all)
                Text("Current").tag(TripFilter.current)
                Text("Upcoming").tag(TripFilter.upcoming)
                Text("Delivered").tag(TripFilter.delivered)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Trips List
            if tripController.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading trips...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTrips.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredTrips) { trip in
                            TripCard(trip: trip)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await tripController.refreshTrips()
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
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all:
            return "car.circle"
        case .current:
            return "car.circle.fill"
        case .upcoming:
            return "clock.arrow.circlepath"
        case .delivered:
            return "checkmark.circle"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "No Trips Found"
        case .current:
            return "No Current Trips"
        case .upcoming:
            return "No Upcoming Trips"
        case .delivered:
            return "No Completed Deliveries"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "There are no trips assigned to you at the moment."
        case .current:
            return "You don't have any trips in progress."
        case .upcoming:
            return "You don't have any upcoming trips scheduled."
        case .delivered:
            return "You haven't completed any deliveries yet."
        }
    }
    
    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            var allTrips: [Trip] = []
            if let currentTrip = tripController.currentTrip,
               currentTrip.status == .inProgress && availabilityManager.isAvailable {
                allTrips.append(currentTrip)
            }
            
            // Only include upcoming trips if driver is available
            if availabilityManager.isAvailable {
                allTrips.append(contentsOf: tripController.upcomingTrips)
            }
            
            // Add delivered trips
            allTrips.append(contentsOf: tripController.recentDeliveries.map { delivery in
                createTripFromDelivery(delivery)
            })
            
            return allTrips
        case .current:
            if let currentTrip = tripController.currentTrip,
               currentTrip.status == .inProgress && availabilityManager.isAvailable {
                return [currentTrip]
            }
            return []
        case .upcoming:
            return availabilityManager.isAvailable ? tripController.upcomingTrips : []
        case .delivered:
            // Convert recent deliveries to Trip objects with improved information
            return tripController.recentDeliveries.map { delivery in
                createTripFromDelivery(delivery)
            }
        }
    }
    
    // Helper function to create Trip from DeliveryDetails
    private func createTripFromDelivery(_ delivery: DeliveryDetails) -> Trip {
        // Extract information from delivery notes
        let deliveryNotes = delivery.notes
        var cargoType = "General Cargo"
        var tripName = "Trip-\(delivery.id.uuidString.prefix(4))"
        var distance = ""
        var startingPoint = ""
        
        // Parse notes to extract structured data
        let lines = deliveryNotes.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("Trip:") {
                tripName = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("Cargo:") {
                cargoType = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("Distance:") {
                distance = String(line.dropFirst(9).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("From:") {
                startingPoint = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            }
        }
        
        // Create a Trip object with the delivery information
        return Trip(
            id: delivery.id,
            name: tripName,
            destination: delivery.location,
            address: delivery.location,
            eta: "",
            distance: distance,
            status: .delivered,
            hasCompletedPreTrip: true,
            hasCompletedPostTrip: true,
            vehicleDetails: Vehicle(
                name: "Vehicle",
                year: 2023,
                make: "Unknown",
                model: "Unknown",
                vin: "Unknown",
                licensePlate: delivery.vehicle,
                vehicleType: .truck,
                color: "Unknown",
                bodyType: .cargo,
                bodySubtype: "Unknown",
                msrp: 0.0,
                pollutionExpiry: Date(),
                insuranceExpiry: Date(),
                status: .available
            ),
            sourceCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            destinationCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            startingPoint: startingPoint.isEmpty ? delivery.location : startingPoint,
            notes: deliveryNotes,
            startTime: nil,
            endTime: nil
        )
    }
}

struct TripCard: View {
    let trip: Trip
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
                
                if !trip.eta.isEmpty && trip.status != .delivered {
                    Text(trip.eta)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(trip.name)
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
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
            
            // Additional information for delivered trips
            if trip.status == .delivered {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vehicle:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.vehicleDetails.licensePlate)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingDetails = true }) {
                        Text("Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            } else {
                Button(action: { showingDetails = true }) {
                    Text("View Details")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingDetails) {
            TripDetailsView(trip: trip)
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

struct TripDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let trip: Trip
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Trip Information")) {
                    TripDetailRow(icon: "number", title: "Trip ID", value: trip.name)
                    TripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                    TripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
                    if !trip.eta.isEmpty {
                        TripDetailRow(icon: "clock.fill", title: "ETA", value: trip.eta)
                    }
                    if !trip.distance.isEmpty {
                        TripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                    }
                }
                
                Section(header: Text("Vehicle Information")) {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                    if trip.vehicleDetails.make != "Unknown" {
                        TripDetailRow(icon: "car.2.fill", title: "Make & Model", value: "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model)")
                    }
                }
                
                // Delivery status section for completed trips
                if trip.status == .delivered {
                    Section(header: Text("Delivery Status")) {
                        TripDetailRow(icon: "checkmark.circle.fill", title: "Status", value: "Completed")
                        TripDetailRow(icon: "clock.badge.checkmark.fill", title: "Pre-Trip Inspection", value: "Completed")
                        TripDetailRow(icon: "checkmark.shield.fill", title: "Post-Trip Inspection", value: "Completed")
                    }
                    
                    // Proof of delivery section for completed trips
                    Section(header: Text("Proof of Delivery")) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("Delivery Receipt")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "signature")
                                Text("Customer Signature")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    // Status section for non-completed trips
                    Section(header: Text("Status")) {
                        TripDetailRow(icon: statusIcon, title: "Current Status", value: statusText)
                        
                        if trip.status == .inProgress {
                            TripDetailRow(
                                icon: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "circle",
                                title: "Pre-Trip Inspection",
                                value: trip.hasCompletedPreTrip ? "Completed" : "Required"
                            )
                            
                            TripDetailRow(
                                icon: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "circle",
                                title: "Post-Trip Inspection",
                                value: trip.hasCompletedPostTrip ? "Completed" : "Required"
                            )
                        }
                    }
                }
                
                // Trip notes section
                if let notes = trip.notes, !notes.isEmpty {
                    Section(header: Text("Notes")) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
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

struct TripDetailRow: View {
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

