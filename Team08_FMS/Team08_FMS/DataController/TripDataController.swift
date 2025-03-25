import SwiftUI
import CoreLocation
import Supabase

enum TripError: Error, Equatable {
    case fetchError(String)
    case decodingError(String)
    case vehicleError(String)
    case updateError(String)
    
    static func == (lhs: TripError, rhs: TripError) -> Bool {
        switch (lhs, rhs) {
        case (.fetchError(let l), .fetchError(let r)): return l == r
        case (.decodingError(let l), .decodingError(let r)): return l == r
        case (.vehicleError(let l), .vehicleError(let r)): return l == r
        case (.updateError(let l), .updateError(let r)): return l == r
        default: return false
        }
    }
}

class TripDataController: ObservableObject {
    static let shared = TripDataController()
    
    @Published var currentTrip: Trip?
    @Published var upcomingTrips: [Trip] = []
    @Published var recentDeliveries: [DeliveryDetails] = []
    @Published var error: TripError?
    @Published var isLoading = false
    
    private let supabaseController = SupabaseDataController.shared
    
    private init() {
        // Start fetching data immediately
        Task {
            await refreshTrips()
        }
    }
    
    @MainActor
    private func fetchTrips() async throws {
        print("Fetching trips...")
        do {
            
            // Create a decoder with custom date decoding strategy
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with different date formats
                let formats = [
                    // Full timestamps with different variations
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    // Date-only format (for pollution_expiry, etc.)
                    "yyyy-MM-dd"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If none of the formats work, try removing microseconds
                if let dotIndex = dateString.firstIndex(of: ".") {
                    let truncated = String(dateString[..<dotIndex])
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: truncated) {
                        return date
                    }
                }
                
                print("Failed to decode date string: \(dateString)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
            }
            
            // Fetch trips with vehicle details in a single query
            let response = try await supabaseController.supabase
                .from("trips")
                .select("""
                    id,
                    destination,
                    trip_status,
                    has_completed_pre_trip,
                    has_completed_post_trip,
                    vehicle_id,
                    driver_id,
                    start_time,
                    end_time,
                    notes,
                    created_at,
                    updated_at,
                    is_deleted,
                    start_latitude,
                    start_longitude,
                    end_latitude,
                    end_longitude,
                    pickup,
                    vehicles (
                        id,
                        name,
                        year,
                        make,
                        model,
                        vin,
                        license_plate,
                        vehicle_type,
                        color,
                        body_type,
                        body_subtype,
                        msrp,
                        pollution_expiry,
                        insurance_expiry,
                        status
                    )
                """)
                .eq("is_deleted", value: false)
                .execute()
            
            // Print raw response for debugging
            print("Raw response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Define a nested struct to match the joined data structure
            struct JoinedTripData: Codable {
                let id: UUID
                let destination: String
                let trip_status: String
                let has_completed_pre_trip: Bool
                let has_completed_post_trip: Bool
                let vehicle_id: UUID
                let driver_id: UUID?
                let start_time: Date?
                let end_time: Date?
                let notes: String?
                let created_at: Date
                let updated_at: Date?
                let is_deleted: Bool
                let start_latitude: Double?
                let start_longitude: Double?
                let end_latitude: Double?
                let end_longitude: Double?
                let pickup: String?
                let vehicles: Vehicle
                
                // Add computed properties to parse distance and fuel cost
                var parsedDistance: String {
                    guard let notes = notes,
                          let distanceRange = notes.range(of: "Distance: "),
                          let endRange = notes[distanceRange.upperBound...].range(of: "\n") else {
                        return "N/A"
                    }
                    return String(notes[distanceRange.upperBound..<endRange.lowerBound])
                }
                
                var parsedFuelCost: String {
                    guard let notes = notes,
                          let fuelRange = notes.range(of: "Estimated Fuel Cost: "),
                          let endRange = notes[fuelRange.upperBound...].range(of: "\n") else {
                        return "N/A"
                    }
                    return String(notes[fuelRange.upperBound..<endRange.lowerBound])
                }
            }
            
            let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)
            
            // Convert joined data to Trip objects
            let tripsWithVehicles = joinedData.map { data -> Trip in
                let supabaseTrip = SupabaseTrip(
                    id: data.id,
                    destination: data.destination,
                    trip_status: data.trip_status,
                    has_completed_pre_trip: data.has_completed_pre_trip,
                    has_completed_post_trip: data.has_completed_post_trip,
                    vehicle_id: data.vehicle_id,
                    driver_id: data.driver_id,
                    start_time: data.start_time,
                    end_time: data.end_time,
                    notes: data.notes,
                    created_at: data.created_at,
                    updated_at: data.updated_at ?? data.created_at,
                    is_deleted: data.is_deleted,
                    start_latitude: data.start_latitude,
                    start_longitude: data.start_longitude,
                    end_latitude: data.end_latitude,
                    end_longitude: data.end_longitude,
                    pickup: data.pickup
                )
                return Trip(from: supabaseTrip, vehicle: data.vehicles)
            }
            
            print("Successfully processed \(tripsWithVehicles.count) trips")
            
            // Update published properties
            await MainActor.run {
                // Find current trip (in progress)
                if let currentTrip = tripsWithVehicles.first(where: { $0.status == TripStatus.inProgress }) {
                    self.currentTrip = currentTrip
                } else {
                    self.currentTrip = nil
                }
                
                // Filter upcoming trips (only pending or assigned)
                self.upcomingTrips = tripsWithVehicles.filter { trip in
                    trip.status == .pending || trip.status == .assigned
                }
                
                // Convert completed/delivered trips to delivery details
                let completedTrips = tripsWithVehicles.filter { trip in 
                    trip.status == .delivered && trip.hasCompletedPostTrip
                }
                
                self.recentDeliveries = completedTrips.compactMap { trip in
                    guard let joinedData = joinedData.first(where: { $0.id == trip.id }) else { return nil }
                    
                    // Extract additional details from notes if available
                    var cargoType = "General Cargo"
                    if let notes = trip.notes,
                       let cargoRange = notes.range(of: "Cargo Type: ") {
                        let noteText = notes[cargoRange.upperBound...]
                        if let endOfCargo = noteText.firstIndex(of: "\n") {
                            cargoType = String(noteText[..<endOfCargo])
                        } else {
                            cargoType = String(noteText)
                        }
                    }
                    
                    // Include distance and fuel cost in the notes
                    let distance = joinedData.parsedDistance
                    let fuelCost = joinedData.parsedFuelCost
                    
                    return DeliveryDetails(
                        id: trip.id,
                        location: trip.destination,
                        date: formatDate(trip.endTime ?? joinedData.created_at),
                        status: "Delivered",
                        driver: "Current Driver",
                        vehicle: trip.vehicleDetails.licensePlate,
                        notes: """
                               Trip: \(trip.name)
                               Cargo: \(cargoType)
                               Distance: \(distance)
                               Estimated Fuel Cost: \(fuelCost)
                               From: \(trip.startingPoint)
                               \(trip.notes ?? "")
                               """
                    )
                }
                
                // Sort recent deliveries by date (newest first)
                self.recentDeliveries.sort { lhs, rhs in
                    // Extract dates from formatted strings (basic parsing)
                    let lhsIsToday = lhs.date.contains("Today")
                    let rhsIsToday = rhs.date.contains("Today")
                    let lhsIsYesterday = lhs.date.contains("Yesterday")
                    let rhsIsYesterday = rhs.date.contains("Yesterday")
                    
                    if lhsIsToday && !rhsIsToday {
                        return true
                    } else if !lhsIsToday && rhsIsToday {
                        return false
                    } else if lhsIsYesterday && !rhsIsToday && !rhsIsYesterday {
                        return true
                    } else if !lhsIsYesterday && !lhsIsToday && (rhsIsToday || rhsIsYesterday) {
                        return false
                    }
                    
                    // If both are from the same period, compare the actual times
                    return lhs.date > rhs.date
                }
                
                self.error = nil
            }
        } catch {
            print("Error fetching trips: \(error)")
            throw TripError.fetchError("Failed to fetch trips: \(error.localizedDescription)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
    
    // Update getCurrentTripData to handle optional currentTrip
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
        return availabilityManager.isAvailable ? upcomingTrips : []
    }
    
    // Add a function to get recentDeliveries data
    func getRecentDeliveries() -> [DeliveryDetails] {
        return recentDeliveries
    }
    
    // Update markTripAsDelivered to throw errors
    @MainActor
    func markTripAsDelivered(trip: Trip) async throws {
        print("Attempting to mark trip \(trip.id) as delivered")
        
        do {
            // First ensure both pre-trip and post-trip inspections are marked as completed in Supabase
            if !trip.hasCompletedPreTrip {
                print("Ensuring pre-trip inspection is marked as completed")
                try await updateTripInspectionStatus(tripId: trip.id, isPreTrip: true, completed: true)
            }
            
            if !trip.hasCompletedPostTrip {
                print("Ensuring post-trip inspection is marked as completed")
                try await updateTripInspectionStatus(tripId: trip.id, isPreTrip: false, completed: true)
            }
            
            // Update trip status in Supabase to delivered
            try await supabaseController.updateTrip(id: trip.id, status: "delivered")
            print("Updated trip status to 'delivered'")
            
            // Update end time in Supabase
            let response = try await supabaseController.databaseFrom("trips")
                .update(["end_time": Date()])
                .eq("id", value: trip.id)
                .execute()
            
            print("Updated trip end_time: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Update local state - remove from current trip
            if let currentTrip = self.currentTrip, currentTrip.id == trip.id {
                self.currentTrip = nil
                print("Removed trip from current trip")
            }
            
            // Create a DeliveryDetails from the trip and add to recent deliveries
            let newDelivery = DeliveryDetails(
                id: trip.id,
                location: trip.destination,
                date: formatDate(trip.endTime ?? Date()),
                status: "Delivered",
                driver: "Current Driver",
                vehicle: trip.vehicleDetails.licensePlate,
                notes: """
                       Trip: \(trip.name)
                       Cargo: General Cargo
                       Distance: \(trip.distance)
                       From: \(trip.startingPoint)
                       \(trip.notes ?? "")
                       """
            )
            
            // Add to recent deliveries - insert at the beginning for newest first
            self.recentDeliveries.insert(newDelivery, at: 0)
            print("Added trip to recent deliveries")
            
            // Refresh trips to ensure everything is in sync with server
            try await fetchTrips()
            print("Trips refreshed after marking as delivered")
        } catch {
            print("Error marking trip as delivered: \(error)")
            throw TripError.updateError("Failed to mark trip as delivered: \(error.localizedDescription)")
        }
    }
    
    // Add a function to start a trip (update from upcoming to current)
    @MainActor
    func startTrip(trip: Trip) async throws {
        print("Starting trip \(trip.id)")
        
        do {
            // Update trip status in Supabase to current
            try await supabaseController.updateTrip(id: trip.id, status: "current")
            print("Updated trip status to 'current'")
            
            // Update start time in Supabase
            let response = try await supabaseController.databaseFrom("trips")
                .update(["start_time": Date()])
                .eq("id", value: trip.id)
                .execute()
            
            print("Updated trip start_time: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Refresh trips to ensure everything is in sync with server
            try await fetchTrips()
            print("Trips refreshed after starting trip")
        } catch {
            print("Error starting trip: \(error)")
            throw TripError.updateError("Failed to start trip: \(error.localizedDescription)")
        }
    }
    
    // Update refreshTrips to handle loading state
    @MainActor
    func refreshTrips() async {
        isLoading = true
        do {
            try await fetchTrips()
        } catch {
            print("Error during refresh: \(error)")
            if let tripError = error as? TripError {
                self.error = tripError
            }
        }
        isLoading = false
    }
    
    @MainActor
    func updateTripInspectionStatus(tripId: UUID, isPreTrip: Bool, completed: Bool) async throws {
        do {
            let field = isPreTrip ? "has_completed_pre_trip" : "has_completed_post_trip"
            print("Updating trip \(tripId) with \(field)=\(completed)")
            
            // First update the database
            let response = try await supabaseController.databaseFrom("trips")
                .update([field: completed])
                .eq("id", value: tripId)
                .execute()
            
            print("Update success response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Then update our local model to reflect changes immediately
            if let currentTrip = self.currentTrip, currentTrip.id == tripId {
                var updatedTrip = currentTrip
                if isPreTrip {
                    updatedTrip.hasCompletedPreTrip = completed
                } else {
                    updatedTrip.hasCompletedPostTrip = completed
                }
                self.currentTrip = updatedTrip
                print("Updated local trip model with \(field)=\(completed)")
            } else {
                print("Warning: Current trip is nil or doesn't match the updated trip ID")
                // Trip might be in upcoming trips
                let index = upcomingTrips.firstIndex(where: { $0.id == tripId })
                if let index = index {
                    var updatedTrip = upcomingTrips[index]
                    if isPreTrip {
                        updatedTrip.hasCompletedPreTrip = completed
                    } else {
                        updatedTrip.hasCompletedPostTrip = completed
                    }
                    upcomingTrips[index] = updatedTrip
                    print("Updated trip in upcoming trips with \(field)=\(completed)")
                }
            }
            
            // Optional: Refresh trips to ensure UI is up-to-date with server state
            // Only do this if you're experiencing synchronization issues
            // Otherwise, the local model update above should be sufficient
            try await fetchTrips()
            
            print("Trips refreshed after inspection update")
        } catch {
            print("Error updating trip inspection status: \(error)")
            throw TripError.updateError("Failed to update trip inspection status: \(error.localizedDescription)")
        }
    }
} 
