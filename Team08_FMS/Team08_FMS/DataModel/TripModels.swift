import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus: String, Codable {
    case pending = "upcoming"
    case inProgress = "current"
    case delivered = "delivered"
    case assigned = "assigned"
}

// Trip Model
struct Trip: Identifiable, Equatable {
    let id: UUID
    let name: String
    let destination: String
    let address: String
    var eta: String
    let distance: String
    var status: TripStatus
    var hasCompletedPreTrip: Bool
    var hasCompletedPostTrip: Bool
    let vehicleDetails: Vehicle
    let notes: String?
    let startTime: Date?
    let endTime: Date?
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let startingPoint: String
    let pickup: String?
    let driverId: UUID?
    
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
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
    
    init(id: UUID = UUID(), name: String, destination: String, address: String, eta: String, distance: String, status: TripStatus, hasCompletedPreTrip: Bool = false, hasCompletedPostTrip: Bool = false, vehicleDetails: Vehicle, sourceCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D, startingPoint: String, notes: String? = nil, startTime: Date? = nil, endTime: Date? = nil, pickup: String? = nil, driverId: UUID? = nil) {
        self.id = id
        self.name = name
        self.destination = destination
        self.address = address
        self.eta = eta
        self.distance = distance
        self.status = status
        self.hasCompletedPreTrip = hasCompletedPreTrip
        self.hasCompletedPostTrip = hasCompletedPostTrip
        self.vehicleDetails = vehicleDetails
        self.sourceCoordinate = sourceCoordinate
        self.destinationCoordinate = destinationCoordinate
        self.startingPoint = startingPoint
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
        self.pickup = pickup
        self.driverId = driverId
    }
    
    static func mockCurrentTrip() -> Trip {
        Trip(
            id: UUID(),
            name: "TRP-001",
            destination: "Nhava Sheva Port Terminal",
            address: "JNPT Port Road, Navi Mumbai, Maharashtra 400707",
            eta: "25 mins",
            distance: "8.5 km",
            status: .inProgress,
            vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available),
            sourceCoordinate: CLLocationCoordinate2D(
                latitude: 19.0178,  // Mumbai region
                longitude: 72.8478
            ),
            destinationCoordinate: CLLocationCoordinate2D(
                latitude: 18.9490,  // JNPT coordinates
                longitude: 72.9492
            ),
            startingPoint: "Mumbai",
            pickup: "Mumbai Central",
            driverId: nil
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
                vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available),
                sourceCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5244,  // Delhi coordinates
                    longitude: 77.2877
                ),
                destinationCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5085,  // ICD Tughlakabad coordinates
                    longitude: 77.2626
                ),
                startingPoint: "New Delhi",
                driverId: nil
            )
        ]
    }
    
    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle) {
        self.id = supabaseTrip.id
        self.name = supabaseTrip.pickup ?? "Trip-\(supabaseTrip.id.uuidString.prefix(8))"
        self.destination = supabaseTrip.destination
        self.address = supabaseTrip.pickup ?? "Unknown"
        self.status = TripStatus(rawValue: supabaseTrip.trip_status) ?? .pending
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
        self.vehicleDetails = vehicle
        self.notes = supabaseTrip.notes
        self.startTime = supabaseTrip.start_time
        self.endTime = supabaseTrip.end_time
        self.pickup = supabaseTrip.pickup
        self.driverId = supabaseTrip.driver_id
        
        // Extract distance and ETA from notes
        if let notes = supabaseTrip.notes,
           let distanceRange = notes.range(of: "Estimated Distance: "),
           let endOfDistance = notes[distanceRange.upperBound...].firstIndex(of: " ") {
            let distanceStr = notes[distanceRange.upperBound..<endOfDistance]
            self.distance = "\(distanceStr) km"
        } else {
            self.distance = "Unknown"
        }
        
        // Calculate ETA based on start and end time
        if let start = supabaseTrip.start_time, let end = supabaseTrip.end_time {
            let duration = end.timeIntervalSince(start)
            self.eta = duration.etaString
        } else {
            self.eta = "Unknown"
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
        self.startingPoint = supabaseTrip.pickup ?? "Unknown"
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
    let trip_status: String
    let has_completed_pre_trip: Bool
    let has_completed_post_trip: Bool
    let vehicle_id: UUID
    let driver_id: UUID?
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
