import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus: String, Codable {
    case pending = "upcoming"
    case inProgress = "current"
    case delivered = "delivered"
    case assigned = "assigned"
}

// Trip Model - Only for main trips
class Trip: Identifiable, Equatable {
    var id: UUID
    var destination: String
    var address: String
    var eta: String
    let distance: String
    var status: TripStatus
    var hasCompletedPreTrip: Bool
    var hasCompletedPostTrip: Bool
    let vehicleDetails: Vehicle
    var notes: String?
    let startTime: Date?
    let endTime: Date?
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let startingPoint: String
    let pickup: String?
    var driverId: UUID?
    
    // Computed property for display purposes
    var displayName: String {
        return pickup ?? "Trip-\(id.uuidString.prefix(8))"
    }
    
    // Static function to create empty trip
    static var empty: Trip {
        let emptyVehicle = Vehicle.empty
        let emptySupabaseTrip = SupabaseTrip(
            id: UUID(),
            destination: "",
            trip_status: "pending",
            has_completed_pre_trip: false,
            has_completed_post_trip: false,
            vehicle_id: emptyVehicle.id,
            driver_id: nil,
            secondary_driver_id: nil,
            start_time: nil,
            end_time: nil,
            notes: "",
            created_at: Date(),
            updated_at: nil,
            is_deleted: false,
            start_latitude: 0,
            start_longitude: 0,
            end_latitude: 0,
            end_longitude: 0,
            pickup: "",
            estimated_distance: 0,
            estimated_time: 0
        )
        return Trip(from: emptySupabaseTrip, vehicle: emptyVehicle)
    }
    
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.id == rhs.id
    }

    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle) {
        self.id = supabaseTrip.id
        self.destination = supabaseTrip.destination
        self.address = supabaseTrip.pickup ?? "N/A"
        self.status = TripStatus(rawValue: supabaseTrip.trip_status) ?? .pending
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
        self.vehicleDetails = vehicle
        self.notes = supabaseTrip.notes
        self.startTime = supabaseTrip.start_time
        self.endTime = supabaseTrip.end_time
        self.pickup = supabaseTrip.pickup
        self.driverId = supabaseTrip.driver_id
        
        // Set distance using estimated_distance if available
        if let estimatedDistance = supabaseTrip.estimated_distance {
            self.distance = String(format: "%.1f km", estimatedDistance)
        } else if let notes = supabaseTrip.notes,
                  let distanceRange = notes.range(of: "Estimated Distance: "),
                  let endRange = notes[distanceRange.upperBound...].range(of: "\n") {
            // Try to extract distance from notes as fallback
            let distanceStr = String(notes[distanceRange.upperBound..<endRange.lowerBound])
            self.distance = distanceStr.trimmingCharacters(in: .whitespaces)
        } else {
            self.distance = "N/A"
        }
        
        // Set ETA using estimated_time if available
        if let estimatedTime = supabaseTrip.estimated_time {
            let hours = Int(estimatedTime)
            let minutes = Int((estimatedTime - Double(hours)) * 60)
            if hours > 0 {
                self.eta = "\(hours)h \(minutes)m"
            } else {
                self.eta = "\(minutes) mins"
            }
        } else if let notes = supabaseTrip.notes,
                  let etaRange = notes.range(of: "Estimated Time: "),
                  let endRange = notes[etaRange.upperBound...].range(of: "\n") {
            // Try to extract ETA from notes as fallback
            let etaStr = String(notes[etaRange.upperBound..<endRange.lowerBound])
            self.eta = etaStr.trimmingCharacters(in: .whitespaces)
        } else {
            self.eta = "N/A"
        }
        
        // Set coordinates from the trip data
        self.sourceCoordinate = CLLocationCoordinate2D(
            latitude: supabaseTrip.start_latitude ?? 0,
            longitude: supabaseTrip.start_longitude ?? 0
        )
        self.destinationCoordinate = CLLocationCoordinate2D(
            latitude: supabaseTrip.end_latitude ?? 0,
            longitude: supabaseTrip.end_longitude ?? 0
        )
        self.startingPoint = supabaseTrip.pickup ?? "N/A"
    }
}

// Separate PickupPoint structure
struct PickupPoint: Identifiable, Equatable, Codable {
    var id: UUID
    var parentTripId: UUID
    var location: String
    var address: String
    var latitude: Double
    var longitude: Double
    var sequence: Int
    var completed: Bool
    var estimatedArrivalTime: Date?
    
    static func == (lhs: PickupPoint, rhs: PickupPoint) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Create an empty pickup point
    static var empty: PickupPoint {
        return PickupPoint(
            id: UUID(),
            parentTripId: UUID(),
            location: "",
            address: "",
            latitude: 0,
            longitude: 0,
            sequence: 0,
            completed: false,
            estimatedArrivalTime: nil
        )
    }
    
    // Create a pickup point with specified values
    static func create(id: UUID = UUID(), parentTripId: UUID, location: String, address: String, 
                     latitude: Double, longitude: Double, sequence: Int, 
                     completed: Bool, estimatedArrivalTime: Date? = nil) -> PickupPoint {
        return PickupPoint(
            id: id,
            parentTripId: parentTripId,
            location: location,
            address: address,
            latitude: latitude,
            longitude: longitude,
            sequence: sequence,
            completed: completed,
            estimatedArrivalTime: estimatedArrivalTime
        )
    }
    
    // Convert to a CLLocationCoordinate2D for map display
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Delivery Details Model
struct DeliveryDetails: Identifiable {
    let id: UUID
    let location: String
    let date: String
    let status: String
    let driver: String
    let vehicle: String
    let notes: String
}

// Supabase Trip Model
struct SupabaseTrip: Codable, Identifiable {
    let id: UUID
    let destination: String
    let trip_status: String
    let has_completed_pre_trip: Bool
    let has_completed_post_trip: Bool
    let vehicle_id: UUID
    let driver_id: UUID?
    let secondary_driver_id: UUID?
    let start_time: Date?
    let end_time: Date?
    let notes: String?
    let created_at: Date?
    let updated_at: Date?
    let is_deleted: Bool
    let start_latitude: Double?
    let start_longitude: Double?
    let end_latitude: Double?
    let end_longitude: Double?
    let pickup: String?
    let estimated_distance: Double?
    let estimated_time: Double?
}

extension TimeInterval {
    var etaString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) mins"
        }
    }
} 
