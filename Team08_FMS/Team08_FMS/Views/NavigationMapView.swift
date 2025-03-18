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
        let type: AnnotationType
        
        enum AnnotationType {
            case source
            case destination
        }
        
        init(coordinate: CLLocationCoordinate2D, title: String?, type: AnnotationType) {
            self.coordinate = coordinate
            self.title = title
            self.type = type
        }
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = followsUserLocation ? .followWithHeading : .none
        
        // Add destination annotation
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update route overlay
        mapView.removeOverlays(mapView.overlays)
        if let route = route {
            mapView.addOverlay(route.polyline)
            
            // If not following user, show the entire route
            if !followsUserLocation {
                mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
                    animated: true
                )
            }
        }
        
        // Update user tracking mode
        mapView.userTrackingMode = followsUserLocation ? .followWithHeading : .none
        
        // Update source point annotation if user location is available
        if let userLocation = userLocation {
            // Remove old source annotations
            let sourceAnnotations = mapView.annotations.filter { ($0 as? MapAnnotation)?.type == .source }
            mapView.removeAnnotations(sourceAnnotations)
            
            // Add new source annotation
            let sourceAnnotation = MapAnnotation(
                coordinate: userLocation,
                title: "Current Location",
                type: .source
            )
            mapView.addAnnotation(sourceAnnotation)
            
            context.coordinator.updateUserLocation(CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NavigationMapView
        var lastLocation: CLLocation?
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routePolyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
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
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize the annotation based on type
            if let markerView = annotationView as? MKMarkerAnnotationView {
                switch mapAnnotation.type {
                case .source:
                    markerView.markerTintColor = .blue
                    markerView.glyphImage = UIImage(systemName: "location.fill")
                case .destination:
                    markerView.markerTintColor = .red
                    markerView.glyphImage = UIImage(systemName: "flag.fill")
                }
            }
            
            return annotationView
        }
        
        func updateUserLocation(_ location: CLLocation) {
            // Only update if location has changed significantly (more than 10 meters)
            if let lastLocation = lastLocation,
               location.distance(from: lastLocation) < 10 {
                return
            }
            
            lastLocation = location
            parent.onLocationUpdate?(location)
        }
    }
} 