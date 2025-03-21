func markTripAsDelivered(trip: Trip) {
    // Create a new delivery detail
    let completedDelivery = DeliveryDetails(
        location: trip.destination,
        date: Date().formatted(date: .numeric, time: .shortened),
        status: "Delivered",
        driver: "Current Driver",
        vehicle: trip.vehicleDetails.licensePlate,
        notes: "Trip \(trip.name) completed successfully. Vehicle: \(trip.vehicleDetails.bodyType.rawValue) (\(trip.vehicleDetails.licensePlate))"
    )
    
    // Add to recent deliveries
    recentDeliveries.insert(completedDelivery, at: 0)
    
    // Create a new trip with updated status
    var updatedTrip = trip
    updatedTrip.tripStatus = .delivered
    updatedTrip.hasCompletedPostTrip = true
    updatedTrip.endTime = Date()
    updatedTrip.updatedAt = Date()
    
    // Update local state
    if currentTrip?.id == trip.id {
        currentTrip = nil  // Clear the current trip since it's delivered
    }
    
    // Update trips array
    if let index = trips.firstIndex(where: { $0.id == trip.id }) {
        trips[index] = updatedTrip
    }
    
    // Remove from upcoming trips if present
    if let index = upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
        upcomingTrips.remove(at: index)
    }
    
    // Update the trip in Supabase
    Task {
        do {
            try await SupabaseDataController.shared.updateTrip(updatedTrip)
            print("Successfully marked trip as delivered in Supabase")
            try await loadTrips() // Refresh the trips list
        } catch {
            print("Error updating trip status: \(error.localizedDescription)")
        }
    }
} 