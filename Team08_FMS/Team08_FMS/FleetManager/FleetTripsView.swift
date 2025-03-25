import SwiftUI

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Simple header section
                HStack {
                    Text("All Trips")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action for adding a new trip
                        print("Add Trip button tapped")
                    }) {
                        Label("Add Trip", systemImage: "plus")
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Trip list
                if tripController.upcomingTrips.isEmpty {
                    print("No upcoming trips to display")
                    EmptyTripsView()
                } else {
                    print("Displaying \(tripController.upcomingTrips.count) trips")
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(tripController.upcomingTrips) { trip in
                                print("Rendering trip: \(trip.name)")
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
            .onChange(of: tripController.error) { error in
                showingError = error != nil
            }
            .onAppear {
                print("FleetTripsView appeared")
                print("Current trips count: \(tripController.upcomingTrips.count)")
                Task {
                    try? await tripController.refreshTrips()
                }
            }
        }
    }
}

// Empty state view
struct EmptyTripsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray4))
            
            Text("No Trips")
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
struct TripCardView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Trip header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                    
                    if !trip.eta.isEmpty {
                        Text("ETA: \(trip.eta)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                TripStatusBadge(status: trip.status)
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
                        Text(trip.address)
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
            
            // Show assignment details if assigned
            if trip.status != .pending {
                let vehicleInfo = "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model) (\(trip.vehicleDetails.licensePlate))"
                Divider()
                
                HStack(spacing: 24) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                        Text(vehicleInfo)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
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
        case .completed: return "Completed"
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending: return Color(.systemGray5)
        case .assigned: return Color.blue.opacity(0.2)
        case .inProgress: return Color.orange.opacity(0.2)
        case .completed: return Color.green.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch status {
        case .pending: return Color(.darkGray)
        case .assigned: return Color.blue
        case .inProgress: return Color.orange
        case .completed: return Color.green
        default: return Color.gray
        }
    }
}

// Trip detail view
struct TripDetailView: View {
    @State private var showingAssignSheet = false
    
    let trip: Trip
    
    var body: some View {
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
        .sheet(isPresented: $showingAssignSheet) {
            // Show assign sheet here
            Text("Assign Trip")
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
