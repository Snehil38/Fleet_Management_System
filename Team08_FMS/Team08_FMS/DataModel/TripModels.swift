import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus: String, Codable {
    case pending = "upcoming"
    case inProgress = "in_progress"
    case completed = "completed"
    case assigned = "assigned"
}

// Trip Model
struct Trip: Identifiable {
    let id: UUID
    let name: String
    let destination: String
    let address: String
    let eta: String
    let distance: String
    var status: TripStatus
    var hasCompletedPreTrip: Bool = false
    var hasCompletedPostTrip: Bool = false
    let vehicleDetails: Vehicle
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let startingPoint: String
    
    static func mockCurrentTrip() -> Trip {
        Trip(
            id: UUID(),
            name: "TRP-001",
            destination: "Nhava Sheva Port Terminal",
            address: "JNPT Port Road, Navi Mumbai, Maharashtra 400707",
            eta: "25 mins",
            distance: "8.5 km",
            status: .inProgress,
            vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available, documents: VehicleDocuments()),
//                VehicleDetails(
//                number: "TRK-001",
//                type: "Heavy Truck",
//                licensePlate: "MH-01-AB-1234",
//                capacity: "40 tons"
//            ),
            sourceCoordinate: CLLocationCoordinate2D(
                latitude: 19.0178,  // Mumbai region
                longitude: 72.8478
            ),
            destinationCoordinate: CLLocationCoordinate2D(
                latitude: 18.9490,  // JNPT coordinates
                longitude: 72.9492
            ),
            startingPoint: "Mumbai"
        )
    }
    
    static func mockUpcomingTrips() -> [Trip] {
        [
            Trip(
                id: UUID(),
                name: "DEL-002",
                destination: "ICD Tughlakabad",
                address: "Tughlakabad, New Delhi, 110020",
                eta: "1.5 hours",
                distance: "22 km",
                status: .pending,
                vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available, documents: VehicleDocuments()),
                sourceCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5244,  // Delhi coordinates
                    longitude: 77.2877
                ),
                destinationCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5085,  // ICD Tughlakabad coordinates
                    longitude: 77.2626
                ),
                startingPoint: "New Delhi"
            )
        ]
    }
}

// Delivery Details Model
struct DeliveryDetails: Identifiable {
    let id = UUID()
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
    let trip_status: TripStatus
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
    
    enum CodingKeys: String, CodingKey {
        case id, destination, trip_status, has_completed_pre_trip, has_completed_post_trip
        case vehicle_id, driver_id, start_time, end_time, notes, created_at, updated_at
        case is_deleted, start_latitude, start_longitude, end_latitude, end_longitude, pickup
    }
}

extension Trip {
    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle) {
        self.id = supabaseTrip.id
        self.name = "TRP-\(supabaseTrip.id.uuidString.prefix(8))"
        self.destination = supabaseTrip.destination
        self.address = supabaseTrip.pickup ?? "Unknown"
        self.eta = supabaseTrip.end_time?.timeIntervalSince(Date()).etaString ?? ""
        self.distance = ""  // Would need to calculate this
        self.status = supabaseTrip.trip_status
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
        self.vehicleDetails = vehicle
        
        if let startLat = supabaseTrip.start_latitude,
           let startLong = supabaseTrip.start_longitude {
            self.sourceCoordinate = CLLocationCoordinate2D(latitude: startLat, longitude: startLong)
        } else {
            self.sourceCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        if let endLat = supabaseTrip.end_latitude,
           let endLong = supabaseTrip.end_longitude {
            self.destinationCoordinate = CLLocationCoordinate2D(latitude: endLat, longitude: endLong)
        } else {
            self.destinationCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        self.startingPoint = supabaseTrip.pickup ?? "Unknown"
    }
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
