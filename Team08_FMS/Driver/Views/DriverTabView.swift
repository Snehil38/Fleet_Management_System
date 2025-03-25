.sheet(isPresented: $showingPreTripInspection) {
    VehicleInspectionView(isPreTrip: true) { success in
        if success {
            Task {
                do {
                    try await tripController.updateTripInspectionStatus(
                        tripId: currentTrip.id,
                        isPreTrip: true,
                        completed: true
                    )
                    // Only update local state after successful Supabase update
                    currentTrip.hasCompletedPreTrip = true
                } catch {
                    alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            alertMessage = "Please resolve all issues before starting the trip"
            showingAlert = true
        }
    }
}
.sheet(isPresented: $showingPostTripInspection) {
    VehicleInspectionView(isPreTrip: false) { success in
        if success {
            Task {
                do {
                    try await tripController.updateTripInspectionStatus(
                        tripId: currentTrip.id,
                        isPreTrip: false,
                        completed: true
                    )
                    // Only update local state after successful Supabase update
                    currentTrip.hasCompletedPostTrip = true
                    markCurrentTripDelivered()
                } catch {
                    alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        } else {
            alertMessage = "Please resolve all issues before completing delivery"
            showingAlert = true
        }
    }
}

// ... existing code ...

private func markCurrentTripDelivered() {
    if currentTrip.hasCompletedPostTrip {
        // Use the TripDataController to mark the trip as delivered
        tripController.markTripAsDelivered(trip: currentTrip)
        
        // The UI will be updated automatically when fetchTrips() completes
        // in the markTripAsDelivered method
    }
} 