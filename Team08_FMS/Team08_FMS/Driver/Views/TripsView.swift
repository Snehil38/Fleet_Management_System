import SwiftUI
import CoreLocation

struct TripsView: View {
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var selectedFilter: TripFilter = .all
    
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
    }
    
    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            var allTrips: [Trip] = []
            if let currentTrip = tripController.currentTrip,
               currentTrip.status == .current && availabilityManager.isAvailable {
                allTrips.append(currentTrip)
            }
            
            // Only include upcoming trips if driver is available
            if availabilityManager.isAvailable {
                allTrips.append(contentsOf: tripController.upcomingTrips)
            }
            
            return allTrips
        case .current:
            if let currentTrip = tripController.currentTrip,
               currentTrip.status == .current && availabilityManager.isAvailable {
                return [currentTrip]
            }
            return []
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
                    status: .delivered,
                    hasCompletedPreTrip: true,
                    hasCompletedPostTrip: true,
                    vehicleId: UUID(),
                    driverId: nil,
                    startTime: nil,
                    endTime: nil,
                    notes: delivery.notes
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
                
                if let startTime = trip.startTime {
                    Text(startTime, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(trip.name)
                .font(.headline)
            
            Text(trip.destination)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(trip.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
        case .current:
            return "Current"
        case .upcoming:
            return "Upcoming"
        case .delivered:
            return "Delivered"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .current:
            return .blue
        case .upcoming:
            return .green
        case .delivered:
            return .gray
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
                    if let startTime = trip.startTime {
                        TripDetailRow(icon: "clock.fill", title: "Start Time", value: startTime.formatted(date: .numeric, time: .shortened))
                    }
                    if let endTime = trip.endTime {
                        TripDetailRow(icon: "clock.fill", title: "End Time", value: endTime.formatted(date: .numeric, time: .shortened))
                    }
                }
                
                Section(header: Text("Vehicle Information")) {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                }
                
                if let notes = trip.notes {
                    Section(header: Text("Notes")) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
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
