@State private var showingSingleDriverAlert = false
@State private var showingDelayWarningAlert = false
@State private var estimatedDelay: Double = 0.0

private func saveTrip() {
    Task {
        guard let vehicle = selectedVehicle else { return }
        let estimatedHours = distance / 40.0
        
        // For long trips, check if we need to confirm single driver
        if distance > 500 && selectedDriverId != nil && selectedSecondaryDriverId == nil {
            // Calculate estimated delay (assuming drivers need 8 hours rest after every 8 hours of driving)
            estimatedDelay = (estimatedHours / 8.0) * 8.0
            showingSingleDriverAlert = true
            return
        }
        
        do {
            let success = try await supabaseDataController.createTrip(
                name: pickupLocation,
                destination: dropoffLocation,
                vehicleId: vehicle.id,
                driverId: selectedDriverId,
                secondaryDriverId: selectedSecondaryDriverId,
                startTime: startDate,
                endTime: deliveryDate,
                startLat: pickupCoordinate?.latitude,
                startLong: pickupCoordinate?.longitude,
                endLat: dropoffCoordinate?.latitude,
                endLong: dropoffCoordinate?.longitude,
                notes: "Cargo Type: \(cargoType)\nEstimated Distance: \(String(format: "%.1f", distance)) km\nEstimated Fuel Cost: $\(String(format: "%.2f", fuelCost))",
                distance: distance,
                time: estimatedHours,
                cost: fuelCost
            )
            
            if success {
                // Update driver status to busy if a driver is assigned
                if let driverId = selectedDriverId {
                    try await crewDataController.updateDriverStatus(driverId, status: .busy)
                }
                
                // Update secondary driver status if present
                if let secondaryDriverId = selectedSecondaryDriverId {
                    try await crewDataController.updateDriverStatus(secondaryDriverId, status: .busy)
                }
                
                try await TripDataController.shared.fetchAllTrips()
                showingSuccessAlert = true
            } else {
                showingAlert = true
                alertMessage = "Failed to create trip. Please try again."
            }
        } catch {
            showingAlert = true
            alertMessage = "Error: \(error.localizedDescription)"
        }
    }
}

var body: some View {
    // ... existing view code ...
    .alert("Single Driver Warning", isPresented: $showingSingleDriverAlert) {
        Button("Cancel", role: .cancel) { }
        Button("Proceed Anyway") {
            showingDelayWarningAlert = true
        }
    } message: {
        Text("This is a long trip (over 500 km) and you have only selected one driver. It is recommended to have two drivers for long trips.")
    }
    .alert("Trip Delay Warning", isPresented: $showingDelayWarningAlert) {
        Button("Cancel", role: .cancel) { }
        Button("Create Trip") {
            // Update delivery date with the delay
            deliveryDate = deliveryDate.addingTimeInterval(estimatedDelay * 3600)
            // Call saveTrip again to actually create the trip
            Task {
                await saveTrip()
            }
        }
    } message: {
        Text("With only one driver, this trip may take approximately \(String(format: "%.1f", estimatedDelay)) hours longer due to required rest periods. The delivery date will be adjusted accordingly. Do you want to proceed?")
    }
    // ... rest of the existing view modifiers ...
} 