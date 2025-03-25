import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus {
    case upcoming, current, delivered
}

// Trip Model
struct Trip: Identifiable {
    let id = UUID()
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
            name: "TRP-001",
            destination: "Nhava Sheva Port Terminal",
            address: "JNPT Port Road, Navi Mumbai, Maharashtra 400707",
            eta: "25 mins",
            distance: "8.5 km",
            status: .current,
            vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available),
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
                name: "DEL-002",
                destination: "ICD Tughlakabad",
                address: "Tughlakabad, New Delhi, 110020",
                eta: "1.5 hours",
                distance: "22 km",
                status: .upcoming,
                vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available),
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
