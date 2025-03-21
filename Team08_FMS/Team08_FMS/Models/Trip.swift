import Foundation
import CoreLocation

struct Trip: Identifiable, Codable {
    let id: UUID
    let name: String
    let destination: String
    let address: String
    var tripStatus: TripStatus
    var hasCompletedPreTrip: Bool  // Changed to var
    var hasCompletedPostTrip: Bool  // Changed to var
    let vehicleId: UUID
    let driverId: UUID?
    let startTime: Date?
    let endTime: Date?
    let notes: String?
    
    var vehicleDetails: Vehicle {
        // This is a computed property that returns a default vehicle
        // In a real app, you would fetch this from your vehicle database
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
        // This is a computed property that returns a default coordinate
        // In a real app, you would fetch this from your location database
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }
    
    var destinationCoordinate: CLLocationCoordinate2D {
        // This is a computed property that returns a default coordinate
        // In a real app, you would fetch this from your location database
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }
    
    // Computed properties for compatibility with existing views
    var eta: String {
        guard let startTime = startTime else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        let now = Date()
        return formatter.string(from: now, to: startTime) ?? "N/A"
    }
    
    var distance: String {
        // Calculate distance between source and destination coordinates
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
        // Extract starting point from trip name (assuming format "Source to Destination")
        name.split(separator: " to ").first?.trimmingCharacters(in: .whitespaces) ?? "Starting Point"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case destination
        case address
        case tripStatus
        case hasCompletedPreTrip = "has_completed_pre_trip"
        case hasCompletedPostTrip = "has_completed_post_trip"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case startTime = "created_at"
        case endTime = "updated_at"
        case notes
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
            notes: "Priority delivery to MIDC warehouse"
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
                notes: "Standard delivery to logistics park"
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
                notes: "Long distance delivery to Gurgaon"
            )
        ]
    }
} 
