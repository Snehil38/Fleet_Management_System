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
        mapView.userTrackingMode = followsUserLocation ? .followWithHeading : .none
        
        // Enhanced map settings for modern look
        mapView.mapType = .mutedStandard
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Apply custom map styling
        mapView.preferredConfiguration = MKStandardMapConfiguration()
        
        // Camera settings for immersive experience
        mapView.camera.altitude = 500
        mapView.camera.pitch = 60
        
        // Add destination annotation with animation
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseInOut) {
            mapView.addAnnotation(destinationAnnotation)
        }
        
        // For simulator testing
        #if targetEnvironment(simulator)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mapView.addGestureRecognizer(panGesture)
        #endif
        
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
        
        // Update user tracking mode with smooth transition
        if mapView.userTrackingMode != (followsUserLocation ? .followWithHeading : .none) {
            UIView.animate(withDuration: 0.3) {
                mapView.userTrackingMode = followsUserLocation ? .followWithHeading : .none
            }
        }
        
        // Update user location with animation
        if let userLocation = userLocation {
            // Update camera position for 3D effect when following user
            if followsUserLocation {
                let camera = MKMapCamera(
                    lookingAtCenter: userLocation,
                    fromDistance: 300, // Closer distance for better detail
                    pitch: 45, // Less aggressive tilt
                    heading: userHeading
                )
                mapView.setCamera(camera, animated: true)
            }
            
            // Update source annotation with animation
            context.coordinator.updateSourceAnnotation(
                at: userLocation,
                on: mapView,
                heading: userHeading
            )
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
        var simulatedSpeed: Double = 5.0 // 5 meters per second (walking speed)
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routePolyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                renderer.lineWidth = 8
                renderer.lineCap = .round
                renderer.lineJoin = .round
                
                // Add second line for better visibility
                let backgroundRenderer = MKPolylineRenderer(polyline: routePolyline)
                backgroundRenderer.strokeColor = UIColor.white.withAlphaComponent(0.3)
                backgroundRenderer.lineWidth = 10
                backgroundRenderer.lineCap = .round
                backgroundRenderer.lineJoin = .round
                
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "UserLocation")
                annotationView.image = UIImage(systemName: "car.fill")
                annotationView.canShowCallout = true
                return annotationView
            }
            
            guard let mapAnnotation = annotation as? MapAnnotation else { return nil }
            
            let identifier = "CustomPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                // Add custom callout with more info
                let detailLabel = UILabel()
                detailLabel.numberOfLines = 2
                detailLabel.font = .systemFont(ofSize: 12)
                annotationView?.detailCalloutAccessoryView = detailLabel
                
                // Add right callout accessory
                let infoButton = UIButton(type: .detailDisclosure)
                infoButton.tintColor = .systemBlue
                annotationView?.rightCalloutAccessoryView = infoButton
            }
            
            annotationView?.annotation = annotation
            
            // Enhanced annotation styling
            switch mapAnnotation.type {
            case .source:
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "location.fill")
                annotationView?.animatesWhenAdded = true
                
                // Add pulse animation
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.duration = 1.0
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                annotationView?.layer.add(pulseAnimation, forKey: "pulse")
                
            case .destination:
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
                annotationView?.displayPriority = .required
                
                // Add bounce animation
                UIView.animate(withDuration: 0.6, delay: 0, options: [.autoreverse, .repeat]) {
                    annotationView?.transform = CGAffineTransform(translationX: 0, y: -8)
                }
            }
            
            // Add shadow for depth
            annotationView?.layer.shadowColor = UIColor.black.cgColor
            annotationView?.layer.shadowOpacity = 0.3
            annotationView?.layer.shadowOffset = CGSize(width: 0, height: 2)
            annotationView?.layer.shadowRadius = 4
            
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
                parent.userLocation = coordinate
                
                // Simulate heading based on movement
                if let lastCoord = lastLocation?.coordinate {
                    let heading = calculateHeading(from: lastCoord, to: coordinate)
                    parent.userHeading = heading
                }
                
                // Update location
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                lastLocation = location
                parent.onLocationUpdate?(location)
            }
            #endif
        }
        
        private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let deltaLong = to.longitude - from.longitude
            let deltaLat = to.latitude - from.latitude
            let heading = (atan2(deltaLong, deltaLat) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
            return heading
        }
        
        func updateSourceAnnotation(at coordinate: CLLocationCoordinate2D, on mapView: MKMapView, heading: Double) {
            // Remove old source annotation if it exists
            if let oldAnnotation = sourceAnnotation {
                mapView.removeAnnotation(oldAnnotation)
            }
            
            // Create new source annotation with distance info
            let distanceString = lastLocation.map { loc -> String in
                let distance = loc.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                return String(format: "Moved %.0f meters", distance)
            } ?? "Starting point"
            
            let newAnnotation = MapAnnotation(
                coordinate: coordinate,
                title: "Current Location",
                subtitle: distanceString,
                type: .source
            )
            sourceAnnotation = newAnnotation
            
            // Add new annotation with animation
            UIView.animate(withDuration: 0.3) {
                mapView.addAnnotation(newAnnotation)
            }
            
            // Update location for distance calculations
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if lastLocation?.distance(from: location) ?? 0 > 5 { // Only update if moved more than 5 meters
                lastLocation = location
                parent.onLocationUpdate?(location)
            }
        }
    }
} 