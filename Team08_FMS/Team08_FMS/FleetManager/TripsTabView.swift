//import SwiftUI
//
//struct TripsTabView: View {
//    @EnvironmentObject private var supabaseDataController: SupabaseDataController
//    @State private var selectedFilter: TripFilter = .all
//    
//    enum TripFilter {
//        case all, active, completed, cancelled
//        
//        var title: String {
//            switch self {
//            case .all: return "All"
//            case .active: return "Active"
//            case .completed: return "Completed"
//            case .cancelled: return "Cancelled"
//            }
//        }
//    }
//    
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 0) {
//                // Filter Segment Control
//                Picker("Trip Filter", selection: $selectedFilter) {
//                    ForEach([TripFilter.all, .active, .completed, .cancelled], id: \.self) { filter in
//                        Text(filter.title)
//                            .tag(filter)
//                    }
//                }
//                .pickerStyle(.segmented)
//                .padding()
//                
//                // Trips List
//                ScrollView {
//                    LazyVStack(spacing: 16) {
//                        ForEach(0..<10) { index in
//                            FleetManagerTripCard(
//                                tripName: "Trip #\(index + 1)",
//                                source: "Mumbai",
//                                destination: "Delhi",
//                                startDate: Date(),
//                                status: index % 3 == 0 ? "Active" : (index % 3 == 1 ? "Completed" : "Cancelled"),
//                                distance: "1,200 km",
//                                cost: "$600"
//                            )
//                        }
//                    }
//                    .padding()
//                }
//            }
//            .navigationTitle("Trips")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button {
//                        // Add filter or sort options
//                    } label: {
//                        Image(systemName: "line.3.horizontal.decrease.circle")
//                            .foregroundColor(.blue)
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct FleetManagerTripCard: View {
//    let tripName: String
//    let source: String
//    let destination: String
//    let startDate: Date
//    let status: String
//    let distance: String
//    let cost: String
//    
//    var statusColor: Color {
//        switch status.lowercased() {
//        case "active": return .blue
//        case "completed": return .green
//        case "cancelled": return .red
//        default: return .gray
//        }
//    }
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            // Header
//            HStack {
//                Text(tripName)
//                    .font(.headline)
//                Spacer()
//                Text(status)
//                    .font(.subheadline)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(statusColor.opacity(0.1))
//                    .foregroundColor(statusColor)
//                    .cornerRadius(8)
//            }
//            
//            Divider()
//            
//            // Route Info
//            HStack(spacing: 12) {
//                // Source
//                VStack(alignment: .leading) {
//                    Text("From")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                    Text(source)
//                        .font(.subheadline)
//                }
//                
//                Image(systemName: "arrow.right")
//                    .foregroundColor(.gray)
//                
//                // Destination
//                VStack(alignment: .leading) {
//                    Text("To")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                    Text(destination)
//                        .font(.subheadline)
//                }
//                
//                Spacer()
//            }
//            
//            Divider()
//            
//            // Trip Details
//            HStack {
//                // Date
//                TripDetailItem(
//                    icon: "calendar",
//                    title: "Start Date",
//                    value: startDate.formatted(date: .abbreviated, time: .shortened)
//                )
//                
//                Spacer()
//                
//                // Distance
//                TripDetailItem(
//                    icon: "arrow.left.and.right",
//                    title: "Distance",
//                    value: distance
//                )
//                
//                Spacer()
//                
//                // Cost
//                TripDetailItem(
//                    icon: "dollarsign.circle",
//                    title: "Cost",
//                    value: cost
//                )
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(16)
//        .shadow(color: Color.black.opacity(0.1), radius: 5)
//    }
//}
//
//struct TripDetailItem: View {
//    let icon: String
//    let title: String
//    let value: String
//    
//    var body: some View {
//        VStack(spacing: 4) {
//            HStack(spacing: 4) {
//                Image(systemName: icon)
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                Text(title)
//                    .font(.caption)
//                    .foregroundColor(.gray)
//            }
//            Text(value)
//                .font(.subheadline)
//        }
//    }
//}
//
//#Preview {
//    TripsTabView()
//        .environmentObject(SupabaseDataController.shared)
//} 
