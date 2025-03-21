import SwiftUI
import CoreLocation

struct CurrentDeliveryCard: View {
    @StateObject private var tripController = TripDataController.shared
    
    var body: some View {
        if let currentTrip = tripController.currentTrip {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Delivery")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "truck")
                    Text("Vehicle Details: \(currentTrip.vehicleDetails.licensePlate)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Trip Locations
                VStack(alignment: .leading, spacing: 0) {
                    // Container for the entire vertical line with destination pin
                    ZStack(alignment: .leading) {
                        // Vertical line that stops at the destination pin
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 2, height: 80)
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        
                        // Progress bar
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 2, height: 40)
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            // Starting Point section
                            HStack(alignment: .top, spacing: 18) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Starting Point")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(currentTrip.name.split(separator: " to ").first ?? "Starting Point")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                    if let startTime = currentTrip.startTime {
                                        Text(startTime, style: .time)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            // Destination section
                            HStack(alignment: .top, spacing: 18) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Destination")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(currentTrip.destination)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(currentTrip.address)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading, -4)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 10)
                
                HStack {
                    VStack {
                        Text("Start Time")
                            .font(.caption)
                        if let startTime = currentTrip.startTime {
                            Text(startTime, style: .time)
                                .font(.body)
                        } else {
                            Text("Not set")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    VStack {
                        Text("Status")
                            .font(.caption)
                        Text(currentTrip.status.rawValue.capitalized)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 4)
        } else {
            VStack {
                Text("No Current Delivery")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 4)
        }
    }
}

#Preview {
    CurrentDeliveryCard()
        .padding()
        .background(Color(.systemGroupedBackground))
} 
