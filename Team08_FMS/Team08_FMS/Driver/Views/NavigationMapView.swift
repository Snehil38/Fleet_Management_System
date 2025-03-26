import SwiftUI
import MapKit

struct NavigationMapView: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var route: MKRoute?
    @Binding var userHeading: Double
    let followsUserLocation: Bool
    
    // For updating ETA and distance
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    class MapAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
        let type: AnnotationType
        
        enum AnnotationType {
            case source
            case destination
        }
        
        init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String? = nil, type: AnnotationType) {
            self.coordinate = coordinate
            self.title = title
            self.subtitle = subtitle
            self.type = type
        }
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Set initial tracking mode to follow with heading
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
        
        // Enhanced map settings for better visualization
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Show more map details
        mapView.showsPointsOfInterest = true
        
        // Add destination annotation
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update route overlay with animation
        if let route = route {
            let currentRouteId = route.polyline.hash
            if context.coordinator.currentRouteId != currentRouteId {
                mapView.removeOverlays(mapView.overlays)
                mapView.addOverlay(route.polyline)
                context.coordinator.currentRouteId = currentRouteId
                
                // If not following user, show the entire route
                if !followsUserLocation {
                    mapView.setVisibleMapRect(
                        route.polyline.boundingMapRect,
                        edgePadding: UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
                        animated: true
                    )
                }
            }
        } else {
            mapView.removeOverlays(mapView.overlays)
            context.coordinator.currentRouteId = nil
        }
        
        // Always ensure we're in the correct tracking mode
        if followsUserLocation && mapView.userTrackingMode != .followWithHeading {
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
        } else if !followsUserLocation && mapView.userTrackingMode != .none {
            mapView.setUserTrackingMode(.none, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NavigationMapView
        var lastLocation: CLLocation?
        var currentRouteId: Int?
        var sourceAnnotation: MapAnnotation?
        var simulatedSpeed: Double = 5.0
        var lastUpdateTime: Date = Date()
        var lastSpeed: Double = 0
        var hasSetInitialPosition = false
        private let minimumUpdateDistance: CLLocationDistance = 5.0
        private let minimumMovementThreshold: CLLocationDistance = 10.0 // 10 meters minimum movement
        private let accuracyThreshold: CLLocationAccuracy = 20.0 // 20 meters accuracy threshold
        private var lastCameraUpdate = Date()
        private let cameraUpdateThreshold: TimeInterval = 1.0 // Minimum time between camera updates
        private var lastRecalculationTime = Date()
        private let recalculationThreshold: TimeInterval = 30.0 // Recalculate route every 30 seconds if off route
        private let offRouteThreshold: CLLocationDistance = 50.0 // Distance in meters to consider off route
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
            super.init()
            print("NavigationMapView Coordinator initialized")
        }
        
        func shouldUpdateCamera(for newLocation: CLLocationCoordinate2D) -> Bool {
            guard let lastLoc = lastLocation else {
                if !hasSetInitialPosition {
                    hasSetInitialPosition = true
                    return true
                }
                return false
            }
            
            let newLoc = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
            let distance = newLoc.distance(from: lastLoc)
            
            return distance >= minimumUpdateDistance
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routePolyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                renderer.lineWidth = 8
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let mapAnnotation = annotation as? MapAnnotation else { return nil }
            
            let identifier = "CustomPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Add right callout accessory for more info
                let infoButton = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = infoButton
            }
            
            annotationView?.annotation = annotation
            
            // Customize the annotation based on type
            switch mapAnnotation.type {
            case .source:
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "location.fill")
                annotationView?.animatesWhenAdded = true
                
                // Add continuous pulse animation
                UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat]) {
                    annotationView?.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }
            case .destination:
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
                // Add continuous bounce animation
                UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat]) {
                    annotationView?.transform = CGAffineTransform(translationX: 0, y: -8)
                }
            }
            
            return annotationView
        }
        
        // For simulator testing
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            #if targetEnvironment(simulator)
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Update user location
            if gesture.state == .changed {
                let now = Date()
                let timeInterval = now.timeIntervalSince(lastUpdateTime)
                
                // Calculate speed based on movement
                if let lastCoord = lastLocation?.coordinate {
                    let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        .distance(from: CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude))
                    lastSpeed = distance / timeInterval
                }
                
                parent.userLocation = coordinate
                
                // Simulate heading based on movement
                if let lastCoord = lastLocation?.coordinate {
                    let heading = calculateHeading(from: lastCoord, to: coordinate)
                    parent.userHeading = heading
                }
                
                // Update location with speed information
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                lastLocation = location
                lastUpdateTime = now
                
                // Only update if moved significantly or speed changed
                if lastLocation?.distance(from: location) ?? 0 > 2 || abs(lastSpeed - simulatedSpeed) > 1 {
                    parent.onLocationUpdate?(location)
                }
            }
            #endif
        }
        
        private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let deltaLong = to.longitude - from.longitude
            let deltaLat = to.latitude - from.latitude
            let heading = (atan2(deltaLong, deltaLat) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
            return heading
        }
        
        // Add method to handle user location updates
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }
            
            // Check for accuracy
            if location.horizontalAccuracy > accuracyThreshold {
                return
            }
            
            // Always update user location immediately
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.userLocation = userLocation.coordinate
                if let heading = userLocation.heading {
                    self.parent.userHeading = heading.trueHeading
                }
            }
            
            // Check if we need to recalculate route
            if let route = parent.route {
                let polyline = route.polyline
                let closest = closestPointOnRoute(to: location.coordinate, route: polyline)
                let distanceFromRoute = distance(from: location.coordinate, to: closest)
                
                let now = Date()
                if distanceFromRoute > offRouteThreshold && 
                   now.timeIntervalSince(lastRecalculationTime) >= recalculationThreshold {
                    // We're off route - recalculate
                    recalculateRoute(from: location.coordinate, to: parent.destination)
                    lastRecalculationTime = now
                }
            }
            
            // Check for significant movement
            if let lastLoc = lastLocation {
                let distance = location.distance(from: lastLoc)
                if distance < minimumMovementThreshold {
                    return
                }
                
                // Calculate distance to destination
                let destinationLocation = CLLocation(latitude: parent.destination.latitude, longitude: parent.destination.longitude)
                let distanceToDestination = location.distance(from: destinationLocation)
                
                // If within 20 meters of destination, remove the route
                if distanceToDestination < 20 {
                    DispatchQueue.main.async {
                        mapView.removeOverlays(mapView.overlays)
                        self.parent.route = nil
                    }
                    return
                }
            }
            
            // Update camera with user's movement
            if parent.followsUserLocation {
                let camera = MKMapCamera(
                    lookingAtCenter: location.coordinate,
                    fromDistance: 150, // Lower altitude for better street view
                    pitch: 70, // More tilted angle for better perspective
                    heading: parent.userHeading
                )
                mapView.setCamera(camera, animated: true)
            }
            
            lastLocation = location
            parent.onLocationUpdate?(location)
        }
        
        private func recalculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            directions.calculate { [weak self] response, error in
                guard let self = self,
                      let route = response?.routes.first else { return }
                
                DispatchQueue.main.async {
                    self.parent.route = route
                }
            }
        }
        
        private func closestPointOnRoute(to point: CLLocationCoordinate2D, route: MKPolyline) -> CLLocationCoordinate2D {
            var closest = route.coordinate
            var minDistance = Double.infinity
            
            // Convert polyline to array of coordinates
            let pointCount = route.pointCount
            let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: pointCount)
            route.getCoordinates(coordinates, range: NSRange(location: 0, length: pointCount))
            
            // Find closest point
            for i in 0..<pointCount {
                let distance = self.distance(from: point, to: coordinates[i])
                if distance < minDistance {
                    minDistance = distance
                    closest = coordinates[i]
                }
            }
            
            coordinates.deallocate()
            return closest
        }
        
        private func distance(from point1: CLLocationCoordinate2D, to point2: CLLocationCoordinate2D) -> CLLocationDistance {
            let location1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
            let location2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
            return location1.distance(from: location2)
        }
        
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("❌ Failed to locate user: \(error.localizedDescription)")
        }
        
        func mapViewWillStartLocatingUser(_ mapView: MKMapView) {
            print("🟢 MapView will start locating user")
        }
        
        func mapViewDidStopLocatingUser(_ mapView: MKMapView) {
            print("🔴 MapView did stop locating user")
        }
        
        // Handle when user tracking mode changes
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if parent.followsUserLocation && mode != .followWithHeading {
                // If we should be following but aren't, reset the mode
                DispatchQueue.main.async {
                    mapView.setUserTrackingMode(.followWithHeading, animated: true)
                }
            }
        }
        
        func updateSourceAnnotation(at coordinate: CLLocationCoordinate2D, on mapView: MKMapView, heading: Double) {
            // Remove old source annotation if it exists
            if let oldAnnotation = sourceAnnotation {
                mapView.removeAnnotation(oldAnnotation)
            }
            
            // Create new source annotation with speed and distance info
            let speedString = String(format: "Speed: %.1f km/h", lastSpeed * 3.6)
            let distanceString = lastLocation.map { loc -> String in
                let distance = loc.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                return String(format: "Distance: %.0f meters", distance)
            } ?? "Starting point"
            
            let newAnnotation = MapAnnotation(
                coordinate: coordinate,
                title: "Current Location",
                subtitle: "\(speedString)\n\(distanceString)",
                type: .source
            )
            sourceAnnotation = newAnnotation
            
            // Add new annotation with animation
            UIView.animate(withDuration: 0.3) {
                mapView.addAnnotation(newAnnotation)
            }
        }
    }
} 
