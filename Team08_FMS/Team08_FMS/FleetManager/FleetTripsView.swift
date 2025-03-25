import SwiftUI
import MapKit

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                Text("All Trips")
                    .font(.title)
                    .padding()
                
                // Trip list
                if tripController.upcomingTrips.isEmpty {
                    EmptyTripsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(tripController.upcomingTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .background(Color(.systemGray6))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(trip.name)
                    .font(.headline)
                Spacer()
                TripStatusBadge(status: trip.status)
            }
            
            // ETA
            Text("ETA: \(trip.eta)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Pickup
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Pickup")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(trip.address)
                    .font(.subheadline)
            }
            
            // Dropoff
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("Dropoff")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(trip.destination)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
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
        case .delivered: return "Completed"
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending: return Color(.systemGray5)
        case .assigned: return Color.blue.opacity(0.2)
        case .inProgress: return Color.orange.opacity(0.2)
        case .delivered: return Color.green.opacity(0.2)
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

// Rename MapAnnotation to LocationAnnotation
struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isPickup: Bool
}

struct TripMapView: View {
    let address: String
    let destination: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var annotations: [LocationAnnotation] = []
    @State private var route: MKRoute?
    
    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    VStack {
                        Circle()
                            .fill(annotation.isPickup ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        Text(annotation.isPickup ? "Pickup" : "Dropoff")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Loading indicator
            if annotations.count == 0 {
                ProgressView()
            }
            
            // Zoom controls
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        // Zoom in button
                        Button(action: {
                            withAnimation {
                                zoomIn()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        // Zoom out button
                        Button(action: {
                            withAnimation {
                                zoomOut()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        // Reset zoom button
                        Button(action: {
                            withAnimation {
                                resetZoom()
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(20)
                    .padding()
                }
            }
        }
        .onAppear {
            geocodeLocations()
        }
    }
    
    // Zoom functions
    private func zoomIn() {
        region.span = MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta * 0.5,
            longitudeDelta: region.span.longitudeDelta * 0.5
        )
    }
    
    private func zoomOut() {
        region.span = MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta * 2.0,
            longitudeDelta: region.span.longitudeDelta * 2.0
        )
    }
    
    private func resetZoom() {
        guard annotations.count == 2 else { return }
        
        let pickup = annotations[0].coordinate
        let dropoff = annotations[1].coordinate
        
        let centerLatitude = (pickup.latitude + dropoff.latitude) / 2
        let centerLongitude = (pickup.longitude + dropoff.longitude) / 2
        
        let latitudeDelta = abs(pickup.latitude - dropoff.latitude) * 1.5
        let longitudeDelta = abs(pickup.longitude - dropoff.longitude) * 1.5
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerLatitude,
                longitude: centerLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeDelta, 0.02),
                longitudeDelta: max(longitudeDelta, 0.02)
            )
        )
    }
    
    private func geocodeLocations() {
        let geocoder = CLGeocoder()
        
        // Geocode pickup location
        geocoder.geocodeAddressString(address + ", India") { placemarks, error in
            if let location = placemarks?.first?.location?.coordinate {
                let pickup = LocationAnnotation(
                    coordinate: location,
                    isPickup: true
                )
                self.annotations.append(pickup)
                updateRegionIfNeeded()
            }
        }
        
        // Geocode dropoff location
        geocoder.geocodeAddressString(destination + ", India") { placemarks, error in
            if let location = placemarks?.first?.location?.coordinate {
                let dropoff = LocationAnnotation(
                    coordinate: location,
                    isPickup: false
                )
                self.annotations.append(dropoff)
                updateRegionIfNeeded()
            }
        }
    }
    
    private func updateRegionIfNeeded() {
        guard annotations.count == 2 else { return }
        
        let pickup = annotations[0].coordinate
        let dropoff = annotations[1].coordinate
        
        // Calculate center
        let centerLatitude = (pickup.latitude + dropoff.latitude) / 2
        let centerLongitude = (pickup.longitude + dropoff.longitude) / 2
        
        // Calculate span
        let latitudeDelta = abs(pickup.latitude - dropoff.latitude) * 1.5
        let longitudeDelta = abs(pickup.longitude - dropoff.longitude) * 1.5
        
        // Update region
        withAnimation {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: centerLatitude,
                    longitude: centerLongitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(latitudeDelta, 0.02),
                    longitudeDelta: max(longitudeDelta, 0.02)
                )
            )
        }
        
        // Calculate route
        calculateRoute(from: pickup, to: dropoff)
    }
    
    private func calculateRoute(from pickup: CLLocationCoordinate2D, to dropoff: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: pickup))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dropoff))
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else { return }
            self.route = route
            
            // Adjust region to show entire route
            let rect = route.polyline.boundingMapRect
            region = MKCoordinateRegion(
                rect.insetBy(dx: -rect.width * 0.2, dy: -rect.height * 0.2)
            )
        }
    }
}

// Custom button style for map controls
struct MapControlButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 2)
    }
}

// Rename MapPolyline to TripMapPolyline
struct TripMapPolyline: View {
    let route: MKRoute
    
    var body: some View {
        TripRoutePolyline(route: route)  // Also renamed RoutePolyline
            .stroke(Color.blue, lineWidth: 4)
    }
}

// Rename RoutePolyline to TripRoutePolyline
struct TripRoutePolyline: Shape {
    let route: MKRoute
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            var points = route.polyline.points()
            let count = route.polyline.pointCount
            
            guard count > 0 else { return }
            
            let firstPoint = points[0]
            let cgPoint = CGPoint(
                x: CGFloat(firstPoint.x),
                y: CGFloat(firstPoint.y)
            )
            path.move(to: cgPoint)
            
            for i in 1..<count {
                let point = points[i]
                let cgPoint = CGPoint(
                    x: CGFloat(point.x),
                    y: CGFloat(point.y)
                )
                path.addLine(to: cgPoint)
            }
        }
    }
}

// Update TripDetailView to use the new MapView
struct TripDetailView: View {
    let trip: Trip
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Trip Status
                VStack(alignment: .leading) {
                    HStack {
                        Text("Trip Status")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(trip.eta)
                            .font(.headline)
                    }
                    
                    TripStatusBadge(status: trip.status)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Trip Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Trip Information")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        LabeledContent(label: "Trip Name", value: trip.name)
                        Divider()
                        LabeledContent(label: "Pickup", value: trip.address)
                        Divider()
                        LabeledContent(label: "Destination", value: trip.destination)
                        Divider()
                        LabeledContent(
                            label: "Start Time",
                            value: trip.startTime.map { formatDate($0) } ?? "Not set"
                        )
                        Divider()
                        LabeledContent(
                            label: "End Time",
                            value: trip.endTime.map { formatDate($0) } ?? "Not set"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Map View
                TripMapView(
                    address: trip.address,
                    destination: trip.destination
                )
                .frame(height: 200)
                .cornerRadius(12)
                
                // Assign Button (only for unassigned trips)
                if trip.status == .pending {
                    Button(action: {
                        // Assign action
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
                    }
                }
            }
            .padding()
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
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
