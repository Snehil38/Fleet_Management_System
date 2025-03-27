import SwiftUI
import MapKit

struct NavigationMapView: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var route: MKRoute?
    @Binding var userHeading: Double
    let followsUserLocation: Bool
    @Binding var isRouteCompleted: Bool
    
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
            case completed
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
        // Disable automatic tracking - we'll handle it manually
        mapView.userTrackingMode = .none
        
        // Set map type to standard for better visibility of buildings and blocks
        mapView.mapType = .standard
        
        // Configure map features
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.pointOfInterestFilter = .includingAll
        
        // Apply custom map styling for better building and block visibility
        let mapConfiguration = MKStandardMapConfiguration()
        mapConfiguration.pointOfInterestFilter = .includingAll
        mapConfiguration.showsTraffic = true
        mapConfiguration.emphasisStyle = .muted
        mapView.preferredConfiguration = mapConfiguration
        
        // Initial camera setup
        let camera = MKMapCamera()
        camera.centerCoordinate = destination
        camera.centerCoordinateDistance = 500
        camera.pitch = 0
        camera.heading = 0
        mapView.camera = camera
        
        // Add destination annotation
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        #if targetEnvironment(simulator)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mapView.addGestureRecognizer(panGesture)
        #endif
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update route overlay based on completion status
        if isRouteCompleted {
            mapView.removeOverlays(mapView.overlays)
            context.coordinator.currentRouteId = nil
        } else if let route = route {
            let currentRouteId = route.polyline.hash
            if context.coordinator.currentRouteId != currentRouteId {
                mapView.removeOverlays(mapView.overlays)
                mapView.addOverlay(route.polyline)
                context.coordinator.currentRouteId = currentRouteId
                
                // Show entire route if not following user
                if !followsUserLocation && !context.coordinator.isUpdatingCamera {
                    let routeRect = route.polyline.boundingMapRect
                    // Add padding to the route rect
                    let paddedRect = routeRect.insetBy(
                        dx: -routeRect.width * 0.1,
                        dy: -routeRect.height * 0.1
                    )
                    let region = mapView.regionThatFits(
                        MKCoordinateRegion(paddedRect)
                    )
                    
                    context.coordinator.queueCameraUpdate {
                        UIView.animate(withDuration: 1.0) {
                            mapView.setRegion(region, animated: false)
                        } completion: { _ in
                            context.coordinator.isUpdatingCamera = false
                        }
                    }
                }
            }
        }
        
        // Update user location and camera
        if let userLocation = userLocation {
            if followsUserLocation && !context.coordinator.isUpdatingCamera {
                context.coordinator.queueCameraUpdate {
                    let camera = MKMapCamera(
                        lookingAtCenter: userLocation,
                        fromDistance: 500,
                        pitch: 45,
                        heading: userHeading
                    )
                    
                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
                        mapView.camera = camera
                    } completion: { _ in
                        context.coordinator.isUpdatingCamera = false
                    }
                }
            }
            
            // Update source annotation
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
        var simulatedSpeed: Double = 5.0
        var updateCount: Int = 0
        var lastUpdateTime: Date = Date()
        var isUpdatingCamera: Bool = false
        var updateTimer: Timer?
        var pendingCameraUpdate: (() -> Void)?
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
            super.init()
            setupUpdateTimer()
        }
        
        deinit {
            updateTimer?.invalidate()
        }
        
        private func setupUpdateTimer() {
            // Increase update interval to 3 seconds
            updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.isUpdatingCamera, let pendingUpdate = self.pendingCameraUpdate {
                    self.isUpdatingCamera = true
                    pendingUpdate()
                    self.pendingCameraUpdate = nil
                }
            }
        }
        
        func queueCameraUpdate(_ update: @escaping () -> Void) {
            pendingCameraUpdate = update
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
                // Update car icon based on route completion
                if parent.isRouteCompleted {
                    annotationView.image = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
                } else {
                    annotationView.image = UIImage(systemName: "car.fill")
                }
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
                if parent.isRouteCompleted {
                    annotationView?.markerTintColor = .systemGreen
                    annotationView?.glyphImage = UIImage(systemName: "checkmark.circle.fill")
                } else {
                    annotationView?.markerTintColor = .systemBlue
                    annotationView?.glyphImage = UIImage(systemName: "location.fill")
                }
                annotationView?.animatesWhenAdded = true
                
            case .destination:
                if parent.isRouteCompleted {
                    annotationView?.markerTintColor = .systemGreen
                    annotationView?.glyphImage = UIImage(systemName: "flag.checkered.circle.fill")
                } else {
                    annotationView?.markerTintColor = .systemRed
                    annotationView?.glyphImage = UIImage(systemName: "flag.fill")
                }
                annotationView?.displayPriority = .required
                
            case .completed:
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphImage = UIImage(systemName: "checkmark.circle.fill")
                annotationView?.displayPriority = .required
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
        
        // Add map region change monitoring with stricter timing
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let now = Date()
            // Increase minimum time between updates to 2 seconds
            if now.timeIntervalSince(lastUpdateTime) < 2.0 {
                return
            }
            lastUpdateTime = now
            
            updateCount += 1
            let span = mapView.region.span
            print("Map Update #\(updateCount)")
            print("New zoom levels - Latitude span: \(span.latitudeDelta), Longitude span: \(span.longitudeDelta)")
            print("Center coordinate: \(mapView.region.center)")
            print("Camera altitude: \(mapView.camera.altitude)")
            print("-------------------")
        }
    }
} 