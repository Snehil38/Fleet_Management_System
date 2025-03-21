import SwiftUI
import CoreLocation

struct TripsView: View {
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var selectedFilter: TripFilter = .all
    @State private var isLoading = true
    @State private var error: Error?
    
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
            
            // Content
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Error loading trips")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadTrips()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTrips.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No trips found")
                        .font(.headline)
                    Text("Check back later for new trips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        }
        .navigationTitle("Trips")
        .task {
            loadTrips()
        }
        .refreshable {
            loadTrips()
        }
    }
    
    private func loadTrips() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await tripController.loadTrips()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
    }
    
    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            var allTrips: [Trip] = []
            if let currentTrip = tripController.currentTrip,
               currentTrip.tripStatus == .current && availabilityManager.isAvailable {
                allTrips.append(currentTrip)
            }
            
            // Only include upcoming trips if driver is available
            if availabilityManager.isAvailable {
                allTrips.append(contentsOf: tripController.upcomingTrips)
            }
            
            // Include delivered trips
            allTrips.append(contentsOf: tripController.trips.filter { $0.tripStatus == .delivered })
            
            return allTrips
        case .current:
            if let currentTrip = tripController.currentTrip,
               currentTrip.tripStatus == .current && availabilityManager.isAvailable {
                return [currentTrip]
            }
            return []
        case .upcoming:
            return availabilityManager.isAvailable ? tripController.upcomingTrips : []
        case .delivered:
            // Show actual delivered trips from the database
            return tripController.trips.filter { $0.tripStatus == .delivered }
        }
    }
}

struct TripCard: View {
    let trip: Trip
    @State private var showingDetails = false
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var showingPreTripInspection = false
    @State private var showingPostTripInspection = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trip ID and Time Info
            HStack {
                Text(trip.name)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Spacer()
                if trip.tripStatus == .upcoming {
                    Text(trip.eta)
                        .font(.system(size: 17))
                        .foregroundColor(.blue)
                        .bold()
                }
            }
            
            // Destination
            Text(trip.destination)
                .font(.system(size: 24))
                .fontWeight(.bold)
            
            // Address
            Text(trip.address)
                .font(.system(size: 17))
                .foregroundColor(.gray)
            
            if trip.tripStatus == .upcoming {
                // Distance
                HStack {
                    Spacer()
                    Text("\(trip.distance)")
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                }
                
                // Action Buttons for upcoming trips
                HStack(spacing: 12) {
                    Button(action: {
                        if availabilityManager.isAvailable {
                            tripController.addTripToQueue(trip)
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Add to Queue")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        tripController.declineTrip(trip)
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Decline")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
            } else if trip.tripStatus == .current {
                // Action Buttons for current trip
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: {
                            if !trip.hasCompletedPreTrip {
                                showingPreTripInspection = true
                            }
                        }) {
                            HStack {
                                Image(systemName: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "circle")
                                Text("Pre-Trip\nInspection")
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                        .disabled(trip.hasCompletedPreTrip)
                        
                        Button(action: {
                            if trip.hasCompletedPreTrip {
                                showingPostTripInspection = true
                            } else {
                                alertMessage = "Complete pre-trip inspection first"
                                showingAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "circle")
                                Text("Post-Trip\nInspection")
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                        .disabled(!trip.hasCompletedPreTrip || trip.hasCompletedPostTrip)
                    }
                    
                    Button(action: {
                        if !trip.hasCompletedPreTrip {
                            alertMessage = "Complete pre-trip inspection first"
                            showingAlert = true
                        } else if trip.hasCompletedPostTrip {
                            tripController.markTripAsDelivered(trip: trip)
                        } else {
                            showingPostTripInspection = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark Delivered")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
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
        .shadow(radius: 2)
        .sheet(isPresented: $showingDetails) {
            TripDetailsView(trip: trip)
        }
        .sheet(isPresented: $showingPreTripInspection) {
            VehicleInspectionView(isPreTrip: true) { success in
                if success {
                    tripController.updateTripPreTripStatus(trip, completed: true)
                }
            }
        }
        .sheet(isPresented: $showingPostTripInspection) {
            VehicleInspectionView(isPreTrip: false) { success in
                if success {
                    tripController.updateTripPostTripStatus(trip, completed: true)
                    if trip.hasCompletedPreTrip {
                        tripController.markTripAsDelivered(trip: trip)
                    }
                }
            }
        }
        .alert("Action Required", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
