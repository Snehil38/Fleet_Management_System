import SwiftUI

struct RouteSelectionView: View {
    let routes: [RouteOption]
    @Binding var selectedRouteId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach(routes) { route in
                RouteOptionRow(route: route, isSelected: route.id == selectedRouteId)
                    .onTapGesture {
                        selectedRouteId = route.id
                    }
            }
        }
        .navigationTitle("Select Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct RouteOptionRow: View {
    let route: RouteOption
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                    if route.isRecommended {
                        Text("Recommended")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(route.eta, systemImage: "clock")
                    Label(route.distance, systemImage: "map")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        RouteSelectionView(
            routes: [
                RouteOption(id: "1", name: "Route 1", eta: "25 mins", distance: "8.5 km", isRecommended: true),
                RouteOption(id: "2", name: "Route 2", eta: "32 mins", distance: "7.8 km", isRecommended: false),
                RouteOption(id: "3", name: "Route 3", eta: "1h 21m", distance: "53 km", isRecommended: false)
            ],
            selectedRouteId: .constant("1")
        )
    }
} 