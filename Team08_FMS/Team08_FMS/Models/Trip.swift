import Foundation
import CoreLocation

enum tripStatus: String, Codable {
    case upcoming
    case current
    case delivered
}

struct Trip: Identifiable, Codable {
    let id: UUID
    let name: String
    let destination: String
    let address: String
    var tripStatus: TripStatus
    var hasCompletedPreTrip: Bool
    var hasCompletedPostTrip: Bool
    let vehicleId: UUID
    let driverId: UUID?
    let startTime: Date?
    let endTime: Date?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?
    let isDeleted: Bool
    
    var vehicleDetails: Vehicle {
        Vehicle(
            id: vehicleId,
            name: "Default Truck",
            year: 2023,
            make: "Default",
            model: "Default",
            vin: "DEFAULT123",
            licensePlate: "TRK-001",
            vehicleType: .truck,
            color: "White",
            bodyType: .cargo,
            bodySubtype: "Standard",
            msrp: 0.0,
            pollutionExpiry: Date().addingTimeInterval(365 * 24 * 60 * 60),
            insuranceExpiry: Date().addingTimeInterval(365 * 24 * 60 * 60),
            status: .available,
            driverId: nil,
            documents: nil
        )
    }
    
    var sourceCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }
    
    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }
    
    var eta: String {
        guard let startTime = startTime else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        let now = Date()
        return formatter.string(from: now, to: startTime) ?? "N/A"
    }
    
    var distance: String {
        let source = CLLocation(latitude: sourceCoordinate.latitude, longitude: sourceCoordinate.longitude)
        let destination = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        let distanceInMeters = source.distance(from: destination)
        
        if distanceInMeters >= 1000 {
            return String(format: "%.1f km", distanceInMeters / 1000)
        } else {
            return String(format: "%.0f m", distanceInMeters)
        }
    }
    
    var startingPoint: String {
        name.split(separator: " to ").first?.trimmingCharacters(in: .whitespaces) ?? "Starting Point"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case destination
        case address
        case tripStatus = "trip_status"
        case hasCompletedPreTrip = "has_completed_pre_trip"
        case hasCompletedPostTrip = "has_completed_post_trip"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
    
    static func mockCurrentTrip() -> Trip {
        Trip(
            id: UUID(),
            name: "Mumbai to Pune",
            destination: "Pune MIDC Warehouse",
            address: "MIDC Industrial Area, Pune",
            tripStatus: .current,
            hasCompletedPreTrip: false,
            hasCompletedPostTrip: false,
            vehicleId: UUID(),
            driverId: UUID(),
            startTime: Date(),
            endTime: nil,
            notes: "Priority delivery to MIDC warehouse",
            createdAt: Date(),
            updatedAt: nil,
            isDeleted: false
        )
    }
    
    static func mockUpcomingTrips() -> [Trip] {
        [
            Trip(
                id: UUID(),
                name: "Pune to Bhiwandi",
                destination: "Bhiwandi Logistics Park",
                address: "Bhiwandi, Maharashtra",
                tripStatus: .upcoming,
                hasCompletedPreTrip: false,
                hasCompletedPostTrip: false,
                vehicleId: UUID(),
                driverId: UUID(),
                startTime: Date().addingTimeInterval(3600),
                endTime: nil,
                notes: "Standard delivery to logistics park",
                createdAt: Date(),
                updatedAt: nil,
                isDeleted: false
            ),
            Trip(
                id: UUID(),
                name: "Bhiwandi to Gurgaon",
                destination: "Gurgaon Logistics Hub",
                address: "Gurgaon, Haryana",
                tripStatus: .upcoming,
                hasCompletedPreTrip: false,
                hasCompletedPostTrip: false,
                vehicleId: UUID(),
                driverId: UUID(),
                startTime: Date().addingTimeInterval(7200),
                endTime: nil,
                notes: "Long distance delivery to Gurgaon",
                createdAt: Date(),
                updatedAt: nil,
                isDeleted: false
            )
        ]
    }
}
