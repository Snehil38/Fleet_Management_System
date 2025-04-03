import SwiftUI
import MapKit

struct TripMapView: View {
    let trip: Trip
    
    @State private var region: MKCoordinateRegion
    @State private var annotations: [LocationAnnotation] = []
    @State private var routeOverlays: [MapRouteOverlay] = []
    
    init(trip: Trip) {
        self.trip = trip
        
        // Default to center of the map somewhere in India if coordinates are not available
        let initialCenter = CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629)
        
        // Try to use the pickup coordinates if available
        let center = trip.sourceCoordinate
        
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                Image(systemName: annotation.iconName)
                    .foregroundColor(annotation.color)
                    .font(.system(size: 24))
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    )
            }
        }
        .overlay(
            ForEach(routeOverlays) { routeOverlay in
                MapOverlayView(overlay: routeOverlay)
            }
        )
        .onAppear {
            setupMapAnnotations()
            calculateRoutes()
        }
    }
    
    private func setupMapAnnotations() {
        var newAnnotations: [LocationAnnotation] = []
        
        // Add pickup point annotation if coordinates available
        let startLat = trip.sourceCoordinate.latitude
        let startLon = trip.sourceCoordinate.longitude
        
        newAnnotations.append(
            LocationAnnotation(
                id: "pickup",
                coordinate: CLLocationCoordinate2D(latitude: startLat, longitude: startLon),
                title: "Pickup",
                subtitle: trip.pickup ?? "Start location",
                iconName: "location.circle.fill",
                color: .blue
            )
        )
        
        // Add mid-point annotation if available
        if let midLat = trip.middle_pickup_latitude, let midLon = trip.middle_pickup_longitude {
            newAnnotations.append(
                LocationAnnotation(
                    id: "midpoint",
                    coordinate: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                    title: "Mid Point",
                    subtitle: trip.middle_Pickup ?? "Mid-point location",
                    iconName: "location.fill.viewfinder",
                    color: .purple
                )
            )
        }
        
        // Add destination annotation
        let endLat = trip.destinationCoordinate.latitude
        let endLon = trip.destinationCoordinate.longitude
        
        newAnnotations.append(
            LocationAnnotation(
                id: "destination",
                coordinate: CLLocationCoordinate2D(latitude: endLat, longitude: endLon),
                title: "Destination",
                subtitle: trip.destination,
                iconName: "mappin.circle.fill",
                color: .red
            )
        )
        
        self.annotations = newAnnotations
        
        // Center and zoom the map to show all annotations
        if !newAnnotations.isEmpty {
            zoomToFitAnnotations()
        }
    }
    
    private func zoomToFitAnnotations() {
        guard !annotations.isEmpty else { return }
        
        var minLat = annotations[0].coordinate.latitude
        var maxLat = annotations[0].coordinate.latitude
        var minLon = annotations[0].coordinate.longitude
        var maxLon = annotations[0].coordinate.longitude
        
        for annotation in annotations {
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
    
    private func calculateRoutes() {
        // Clear existing routes
        routeOverlays = []
        
        let startCoordinate = trip.sourceCoordinate
        let endCoordinate = trip.destinationCoordinate
        
        // If we have a mid-point, create a route with waypoints
        if let midLat = trip.middle_pickup_latitude, let midLon = trip.middle_pickup_longitude {
            let midPointCoordinate = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
            
            // First segment: Start to Mid-point
            calculateRouteBetween(from: startCoordinate, to: midPointCoordinate) { route in
                if let route = route {
                    self.routeOverlays.append(MapRouteOverlay(id: "route1", route: route, color: .blue))
                }
            }
            
            // Second segment: Mid-point to Destination
            calculateRouteBetween(from: midPointCoordinate, to: endCoordinate) { route in
                if let route = route {
                    self.routeOverlays.append(MapRouteOverlay(id: "route2", route: route, color: .red))
                }
            }
        } else {
            // Direct route from start to end
            calculateRouteBetween(from: startCoordinate, to: endCoordinate) { route in
                if let route = route {
                    self.routeOverlays.append(MapRouteOverlay(id: "route", route: route, color: .blue))
                }
            }
        }
    }
    
    private func calculateRouteBetween(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, completion: @escaping (MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.transportType = .automobile
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("Error calculating route: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let route = response?.routes.first {
                completion(route)
            } else {
                completion(nil)
            }
        }
    }
}

// Updated LocationAnnotation to conform to the Identifiable protocol for Map view
struct LocationAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
}

struct MapRouteOverlay: Identifiable {
    let id: String
    let route: MKRoute
    let color: Color
}

struct MapOverlayView: UIViewRepresentable {
    let overlay: MapRouteOverlay
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Clear existing overlays
        uiView.removeOverlays(uiView.overlays)
        
        // Add the route overlay
        uiView.addOverlay(overlay.route.polyline)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapOverlayView
        
        init(_ parent: MapOverlayView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.overlay.color)
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
} 
