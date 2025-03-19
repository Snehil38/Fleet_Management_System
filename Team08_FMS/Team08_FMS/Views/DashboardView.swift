import SwiftUI

struct DashboardView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // ... existing dashboard content ...
                
                // Remove any availability toggle from here
                // Only show the current status without the ability to change it
                Section(header: Text("Status")) {
                    HStack {
                        Text("Availability")
                        Spacer()
                        Text(availabilityManager.isAvailable ? "Available" : "Unavailable")
                            .foregroundColor(availabilityManager.isAvailable ? .green : .red)
                    }
                }
                
                // ... rest of the dashboard content ...
            }
            .navigationTitle("Dashboard")
        }
    }
} 