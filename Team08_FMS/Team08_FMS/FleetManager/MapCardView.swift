import SwiftUI
import MapKit

// A simple model to represent a map annotation item.
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct DriverMapCardView: View {
    // Input parameters for the view
    let driverID: UUID
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    
    // State to hold the driver's coordinate and map region.
    @State private var driverCoordinate: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var annotations: [MapAnnotationItem] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading driver location...")
                    .padding()
            } else {
                Map(coordinateRegion: $region, annotationItems: annotations) { item in
                    // Use a different tint color based on annotation title.
                    MapMarker(coordinate: item.coordinate, tint: markerColor(for: item.title))
                }
                .frame(height: 300)
                .cornerRadius(12)
                .shadow(radius: 5)
            }
        }
        .padding()
        .onAppear {
            // Fetch the driver's location when the view appears.
            Task {
                do {
                    let driverLocation = try await SupabaseDataController.shared.fetchDriverLocation(userID: driverID)
                    
                    // Ensure we have valid coordinates.
                    if let lat = driverLocation.latitude, let lon = driverLocation.longitude {
                        let driverCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        driverCoordinate = driverCoord
                        
                        // Center the map around the driver's location.
                        region.center = driverCoord
                        
                        // Create annotations for driver, source, and destination.
                        annotations = [
                            MapAnnotationItem(coordinate: driverCoord, title: "Driver"),
                            MapAnnotationItem(coordinate: sourceCoordinate, title: "Source"),
                            MapAnnotationItem(coordinate: destinationCoordinate, title: "Destination")
                        ]
                    }
                    isLoading = false
                } catch {
                    print("Error fetching driver location: \(error.localizedDescription)")
                    isLoading = false
                }
            }
            
            // Optionally subscribe to realtime updates.
            SupabaseDataController.shared.subscribeToLocation(driverID: driverID)
        }
    }
    
    // Helper function to choose a color based on the annotation type.
    private func markerColor(for title: String) -> Color {
        switch title {
        case "Driver":
            return .blue
        case "Source":
            return .green
        case "Destination":
            return .red
        default:
            return .gray
        }
    }
}

struct DriverMapCardView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample coordinates for preview purposes.
        let driverID = UUID()
        let sourceCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let destinationCoordinate = CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2711)
        DriverMapCardView(driverID: driverID, sourceCoordinate: sourceCoordinate, destinationCoordinate: destinationCoordinate)
    }
}
