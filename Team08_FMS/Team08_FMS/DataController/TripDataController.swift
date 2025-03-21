import Foundation
import SwiftUI
import CoreLocation

class TripDataController: ObservableObject {
    static let shared = TripDataController()
    
    @Published var trips: [Trip] = []
    @Published var currentTrip: Trip?
    @Published var upcomingTrips: [Trip] = []
    @Published var recentDeliveries: [DeliveryDetails] = []
    @Published var queuedTrips: [Trip] = []
    
    private init() {
        // Initialize with empty state
        // Data will be loaded when view appears
    }
    
    func loadTrips() async throws {
        do {
            let fetchedTrips = try await SupabaseDataController.shared.fetchTrips()
            await MainActor.run {
                trips = fetchedTrips
                
                // Update current and upcoming trips
                currentTrip = fetchedTrips.first(where: { $0.tripStatus == .current })
                upcomingTrips = fetchedTrips.filter { $0.tripStatus == .upcoming }
            }
        } catch {
            print("Error loading trips: \(error.localizedDescription)")
            // Clear all data in case of error
            await MainActor.run {
                trips = []
                currentTrip = nil
                upcomingTrips = []
            }
            throw error // Rethrow the error so it can be handled by the view
        }
    }
    
    func loadTripsByDriver(driverId: UUID) async throws -> [Trip] {
        return try await SupabaseDataController.shared.fetchTripsByDriver(driverId: driverId)
    }
    
    func loadTripsByVehicle(vehicleId: UUID) async throws -> [Trip] {
        return try await SupabaseDataController.shared.fetchTripsByVehicle(vehicleId: vehicleId)
    }
    
    func loadTripsByStatus(status: TripStatus) async throws -> [Trip] {
        return try await SupabaseDataController.shared.fetchTripsByStatus(status: status)
    }
    
    func update() {
        Task {
            do {
                try await loadTrips()
            } catch {
                print("Error updating trips: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper function to get trips for the current page
    func getPagedTrips(page: Int, itemsPerPage: Int) -> [Trip] {
        let startIndex = (page - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, trips.count)
        
        guard startIndex < trips.count else {
            return []
        }
        
        return Array(trips[startIndex..<endIndex])
    }
    
    // Get the current trip data
    func getCurrentTripData() -> Trip? {
        return currentTrip
    }
    
    // Add a function to get upcomingTrips data
    func getUpcomingTrips() -> [Trip] {
        return upcomingTrips
    }
    
    // Add a function to get filtered trips based on driver availability
    func getAvailabilityFilteredTrips() -> [Trip] {
        let availabilityManager = DriverAvailabilityManager.shared
        
        // If driver is unavailable, return empty array
        if !availabilityManager.isAvailable {
            return []
        }
        
        // Otherwise return all upcoming trips
        return upcomingTrips
    }
    
    // Add a function to get recentDeliveries data
    func getRecentDeliveries() -> [DeliveryDetails] {
        return recentDeliveries
    }
    
    // Add a function to mark a trip as delivered
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
        
        // If this is the current trip, update it
        if currentTrip?.id == trip.id {
            currentTrip = updatedTrip
        }
        
        // Update the trip in Supabase
        Task {
            do {
                try await SupabaseDataController.shared.updateTrip(updatedTrip)
                update() // Refresh the trips list
            } catch {
                print("Error updating trip status: \(error.localizedDescription)")
            }
        }
    }
    
    func updateTripPreTripStatus(_ trip: Trip, completed: Bool) {
        var updatedTrip = trip
        updatedTrip.hasCompletedPreTrip = completed
        
        if currentTrip?.id == trip.id {
            currentTrip = updatedTrip
        }
        
        Task {
            do {
                try await SupabaseDataController.shared.updateTrip(updatedTrip)
                update()
            } catch {
                print("Error updating pre-trip status: \(error.localizedDescription)")
            }
        }
    }
    
    func updateTripPostTripStatus(_ trip: Trip, completed: Bool) {
        var updatedTrip = trip
        updatedTrip.hasCompletedPostTrip = completed
        
        if currentTrip?.id == trip.id {
            currentTrip = updatedTrip
        }
        
        Task {
            do {
                try await SupabaseDataController.shared.updateTrip(updatedTrip)
                update()
            } catch {
                print("Error updating post-trip status: \(error.localizedDescription)")
            }
        }
    }
    
    func addTripToQueue(_ trip: Trip) {
        if let index = upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = upcomingTrips.remove(at: index)
            updatedTrip.tripStatus = .current
            currentTrip = updatedTrip
            objectWillChange.send()
            
            // Update the trip status in the database
            Task {
                do {
                    try await SupabaseDataController.shared.updateTrip(updatedTrip)
                } catch {
                    print("Error updating trip status: \(error.localizedDescription)")
                    // Revert changes if update fails
                    upcomingTrips.insert(trip, at: index)
                    currentTrip = nil
                    objectWillChange.send()
                }
            }
        }
    }
    
    func declineTrip(_ trip: Trip) {
        if let index = upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
            upcomingTrips.remove(at: index)
            objectWillChange.send()
            
            // Update the trip status in the database
            var updatedTrip = trip
            updatedTrip.tripStatus = .delivered // Using delivered as declined for now
            Task {
                do {
                    try await SupabaseDataController.shared.updateTrip(updatedTrip)
                } catch {
                    print("Error declining trip: \(error.localizedDescription)")
                }
            }
        }
    }
} 
