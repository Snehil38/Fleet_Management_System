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
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredTrips) { trip in
                        TripCard(trip: trip)
                    }
                }
                .padding()
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
        .onChange(of: tripController.error) { error in
            showingError = error != nil
        }
    }
    
    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            var allTrips: [Trip] = []
            if tripController.currentTrip.status == .inProgress && availabilityManager.isAvailable {
                allTrips.append(tripController.currentTrip)
            }
            
            // Only include upcoming trips if driver is available
            if availabilityManager.isAvailable {
                allTrips.append(contentsOf: tripController.upcomingTrips)
            }
            
            return allTrips
        case .current:
            return tripController.currentTrip.status == .inProgress && availabilityManager.isAvailable ? 
                [tripController.currentTrip] : []
        case .upcoming:
            return availabilityManager.isAvailable ? tripController.upcomingTrips : []
        case .delivered:
            // Filter recent deliveries to show only delivered trips
            return tripController.recentDeliveries.map { delivery in
                Trip(
                    id: UUID(),
                    name: delivery.vehicle,
                    destination: delivery.location,
                    address: delivery.location,
                    eta: "",
                    distance: "",
                    status: .completed,
                    vehicleDetails: Vehicle(
                        name: "Tesla",
                        year: 2023,
                        make: "Tesla",
                        model: "Model Y",
                        vin: "5YJYGDEE3MF123456",
                        licensePlate: "TESLA88",
                        vehicleType: .car,
                        color: "White",
                        bodyType: .suv,
                        bodySubtype: "Electric",
                        msrp: 55000.0,
                        pollutionExpiry: Date(),
                        insuranceExpiry: Date(),
                        status: .available,
                        documents: VehicleDocuments()
                    ),
                    sourceCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    destinationCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    startingPoint: delivery.location
                )
            }
        }
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
                
                if !trip.eta.isEmpty {
                    Text(trip.eta)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(trip.name)
                .font(.headline)
            
            Text(trip.destination)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !trip.distance.isEmpty {
                Text(trip.distance)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showingDetails = true }) {
                Text("View Details")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
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
        case .completed:
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
        case .completed:
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
                    if !trip.vehicleDetails.licensePlate.isEmpty {
                        TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                    }
                }
            }
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

#Preview {
    NavigationView {
        TripsView()
    }
} 
