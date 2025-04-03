import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus: String, Codable {
    case pending = "upcoming"
    case inProgress = "current"
    case delivered = "delivered"
    case assigned = "assigned"
}
//
//class Trip: Identifiable, ObservableObject {
//    let id: UUID
//    let destination: String
//    @Published var status: TripStatus
//    @Published var hasCompletedPreTrip: Bool
//    @Published var hasCompletedPostTrip: Bool
//    let vehicleId: UUID
//    let driverId: UUID?
//    let secondaryDriverId: UUID?
//    let startTime: Date?
//    let endTime: Date?
//    let notes: String?
//    let createdAt: Date
//    let updatedAt: Date
//    let isDeleted: Bool
//    let startLatitude: Double?
//    let startLongitude: Double?
//    let endLatitude: Double?
//    let endLongitude: Double?
//    let pickup: String?
//    let estimatedDistance: Double?
//    let estimatedTime: Double?
//    let midPoint: String?
//    let midPointLatitude: Double?
//    let midPointLongitude: Double?
//    let vehicle: Vehicle?
//    
//    // Display-related properties
//    let address: String
//    let eta: String
//    let distance: String
//    
//    var displayName: String {
//        if let notes = notes {
//            if let tripRange = notes.range(of: "Trip: "),
//               let endRange = notes[tripRange.upperBound...].range(of: "\n") {
//                return String(notes[tripRange.upperBound..<endRange.lowerBound])
//            }
//        }
//        return "Trip \(id.uuidString.prefix(8))"
//    }
//    
//    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle? = nil) {
//        self.id = supabaseTrip.id
//        self.destination = supabaseTrip.destination
//        self.status = supabaseTrip.trip_status
//        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
//        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
//        self.vehicleId = supabaseTrip.vehicle_id
//        self.driverId = supabaseTrip.driver_id
//        self.secondaryDriverId = supabaseTrip.secondary_driver_id
//        self.startTime = supabaseTrip.start_time
//        self.endTime = supabaseTrip.end_time
//        self.notes = supabaseTrip.notes
//        self.createdAt = supabaseTrip.created_at
//        self.updatedAt = supabaseTrip.updated_at ?? supabaseTrip.created_at
//        self.isDeleted = supabaseTrip.is_deleted
//        self.startLatitude = supabaseTrip.start_latitude
//        self.startLongitude = supabaseTrip.start_longitude
//        self.endLatitude = supabaseTrip.end_latitude
//        self.endLongitude = supabaseTrip.end_longitude
//        self.pickup = supabaseTrip.pickup
//        self.estimatedDistance = supabaseTrip.estimated_distance
//        self.estimatedTime = supabaseTrip.estimated_time
//        self.midPoint = supabaseTrip.midPoint
//        self.midPointLatitude = supabaseTrip.midPointLat
//        self.midPointLongitude = supabaseTrip.midPointLong
//        self.vehicle = vehicle
//        
//        // Initialize display-related properties
//        self.address = supabaseTrip.pickup ?? "No address provided"
//        self.eta = ""  // ETA will be calculated later
//        self.distance = String(format: "%.1f km", supabaseTrip.estimated_distance ?? 0.0)
//    }
//}

// Trip Model
struct Trip: Identifiable, Equatable {
    let id: UUID
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
    let driverId: UUID?
    let middle_Pickup: String?
    let middle_pickup_latitude: Double?
    let middle_pickup_longitude: Double?
    
    // Computed property for display purposes
    var displayName: String {
        if let notes = notes {
            if let tripRange = notes.range(of: "Trip: "),
               let endRange = notes[tripRange.upperBound...].range(of: "\n") {
                return String(notes[tripRange.upperBound..<endRange.lowerBound])
            }
        }
        return "Trip \(id.uuidString.prefix(8))"
    }
    
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.destination == rhs.destination &&
               lhs.address == rhs.address &&
               lhs.eta == rhs.eta &&
               lhs.distance == rhs.distance &&
               lhs.status == rhs.status &&
               lhs.hasCompletedPreTrip == rhs.hasCompletedPreTrip &&
               lhs.hasCompletedPostTrip == rhs.hasCompletedPostTrip &&
               lhs.vehicleDetails == rhs.vehicleDetails &&
               lhs.notes == rhs.notes &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.sourceCoordinate.latitude == rhs.sourceCoordinate.latitude &&
               lhs.sourceCoordinate.longitude == rhs.sourceCoordinate.longitude &&
               lhs.destinationCoordinate.latitude == rhs.destinationCoordinate.latitude &&
               lhs.destinationCoordinate.longitude == rhs.destinationCoordinate.longitude &&
               lhs.startingPoint == rhs.startingPoint &&
               lhs.pickup == rhs.pickup &&
               lhs.driverId == rhs.driverId
    }
    
    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle? = nil) {
        self.id = supabaseTrip.id
        self.destination = supabaseTrip.destination
        self.status = supabaseTrip.trip_status
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
//        self.vehicleId = supabaseTrip.vehicle_id
        self.driverId = supabaseTrip.driver_id
//        self.secondaryDriverId = supabaseTrip.secondary_driver_id
        self.startTime = supabaseTrip.start_time
        self.endTime = supabaseTrip.end_time
        self.notes = supabaseTrip.notes
//        self.createdAt = supabaseTrip.created_at
//        self.updatedAt = supabaseTrip.updated_at ?? supabaseTrip.created_at
//        self.isDeleted = supabaseTrip.is_deleted
        self.sourceCoordinate = CLLocationCoordinate2D(latitude: supabaseTrip.start_longitude! , longitude: supabaseTrip.end_latitude!)
        self.destinationCoordinate = CLLocationCoordinate2D(latitude: supabaseTrip.end_longitude! , longitude: supabaseTrip.end_latitude!)
        self.startingPoint = supabaseTrip.pickup!
//        self.startLongitude = supabaseTrip.start_longitude
//        self.endLatitude = supabaseTrip.end_latitude
//        self.endLongitude = supabaseTrip.end_longitude
        self.pickup = supabaseTrip.pickup
//        self.estimatedDistance = supabaseTrip.estimated_distance
//        self.estimatedTime = supabaseTrip.estimated_time
        self.middle_Pickup = supabaseTrip.midPoint
        self.middle_pickup_latitude = supabaseTrip.midPointLat
        self.middle_pickup_longitude = supabaseTrip.midPointLong
        self.vehicleDetails = vehicle!
        
        // Initialize display-related properties
        self.address = supabaseTrip.pickup ?? "No address provided"
        self.eta = ""  // ETA will be calculated later
        self.distance = String(format: "%.1f km", supabaseTrip.estimated_distance ?? 0.0)
    }

}

// Delivery Details Model
struct DeliveryDetails: Identifiable, Equatable {
    let id: UUID
    let location: String
    let date: String
    let status: String
    let driver: String
    let vehicle: String
    let notes: String
    
    init(id: UUID = UUID(), location: String, date: String, status: String, driver: String, vehicle: String, notes: String) {
        self.id = id
        self.location = location
        self.date = date
        self.status = status
        self.driver = driver
        self.vehicle = vehicle
        self.notes = notes
    }
    
    static func == (lhs: DeliveryDetails, rhs: DeliveryDetails) -> Bool {
        return lhs.id == rhs.id &&
               lhs.location == rhs.location &&
               lhs.date == rhs.date &&
               lhs.status == rhs.status &&
               lhs.driver == rhs.driver &&
               lhs.vehicle == rhs.vehicle &&
               lhs.notes == rhs.notes
    }
}

// Supabase Trip Model
struct SupabaseTrip: Codable, Identifiable {
    let id: UUID
    let destination: String
    let trip_status: TripStatus
    let has_completed_pre_trip: Bool
    let has_completed_post_trip: Bool
    let vehicle_id: UUID
    let driver_id: UUID?
    let secondary_driver_id: UUID?
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
    let estimated_distance: Double?
    let estimated_time: Double?
    let midPoint: String?
    let midPointLat: Double?
    let midPointLong: Double?
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
