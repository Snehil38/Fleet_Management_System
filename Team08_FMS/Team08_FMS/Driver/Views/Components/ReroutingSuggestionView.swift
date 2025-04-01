import SwiftUI
import MapKit

struct ReroutingSuggestionView: View {
    @ObservedObject var tripController: TripDataController
    @Binding var isPresented: Bool
    let onRouteSelected: (MKRoute) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Faster Route Available")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            if let currentRoute = tripController.currentRoute {
                // Current Route Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Route")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    let currentDetails = tripController.getRouteDetails(currentRoute)
                    HStack {
                        Label(currentDetails.distance, systemImage: "arrow.left.and.right")
                        Spacer()
                        Label(currentDetails.time, systemImage: "clock")
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Alternate Routes
                if !tripController.alternateRoutes.isEmpty {
                    Text("Suggested Routes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(tripController.alternateRoutes, id: \.self) { route in
                        let details = tripController.getRouteDetails(route)
                        let timeSaved = currentRoute.expectedTravelTime - route.expectedTravelTime
                        let timeSavedMinutes = Int(timeSaved / 60)
                        
                        Button(action: {
                            onRouteSelected(route)
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Label(details.distance, systemImage: "arrow.left.and.right")
                                        Spacer()
                                        Label(details.time, systemImage: "clock")
                                    }
                                    Text("Saves \(timeSavedMinutes) minutes")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

#Preview {
    ReroutingSuggestionView(
        tripController: TripDataController.shared,
        isPresented: .constant(true),
        onRouteSelected: { _ in }
    )
} 