import SwiftUI
import CoreLocation

class TripDataController: ObservableObject {
    static let shared = TripDataController()
    
    @Published var currentTrip: Trip
    @Published var upcomingTrips: [Trip]
    @Published var recentDeliveries: [DeliveryDetails]
    
    private init() {
        // Initialize with sample data
        let (current, upcoming, recent) = Self.getInitialTrips()
        self.currentTrip = current
        self.upcomingTrips = upcoming
        self.recentDeliveries = recent
    }
    
    private static func getInitialTrips() -> (current: Trip, upcoming: [Trip], recent: [DeliveryDetails]) {
        let currentTrip = Trip(
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
        
        let upcomingTrips = [
            Trip(
                name: "DEL-002",
                destination: "ICD Tughlakabad", 
                address: "Tughlakabad, New Delhi, 110020", 
                eta: "1.5 hours", 
                distance: "22 km",
                status: .pending,
                vehicleDetails: Vehicle(
                    name: "Ford",
                    year: 2018,
                    make: "Ford",
                    model: "F-150",
                    vin: "1FTFW1E5XJFC12345",
                    licensePlate: "ABC123",
                    vehicleType: .truck,
                    color: "Red",
                    bodyType: .pickup,
                    bodySubtype: "SuperCrew",
                    msrp: 45000.0,
                    pollutionExpiry: Date(),
                    insuranceExpiry: Date(),
                    status: .inService,
                    documents: VehicleDocuments()
                ),
                sourceCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5244,
                    longitude: 77.2877
                ),
                destinationCoordinate: CLLocationCoordinate2D(
                    latitude: 28.5085,
                    longitude: 77.2626
                ),
                startingPoint: "New Delhi"
            ),
            Trip(
                name: "BLR-003",
                destination: "Whitefield Logistics Hub", 
                address: "ITPL Main Road, Whitefield, Bangalore 560066", 
                eta: "45 mins", 
                distance: "15 km",
                status: .pending,
                vehicleDetails: Vehicle(
                    name: "Toyota",
                    year: 2022,
                    make: "Toyota",
                    model: "Camry",
                    vin: "4T1BF1FK6JU123456",
                    licensePlate: "XYZ789",
                    vehicleType: .car,
                    color: "Blue",
                    bodyType: .sedan,
                    bodySubtype: "Hybrid",
                    msrp: 28000.0,
                    pollutionExpiry: Date(),
                    insuranceExpiry: Date(),
                    status: .available,
                    documents: VehicleDocuments()
                ),
                sourceCoordinate: CLLocationCoordinate2D(
                    latitude: 12.9716,
                    longitude: 77.5946
                ),
                destinationCoordinate: CLLocationCoordinate2D(
                    latitude: 12.9698,
                    longitude: 77.7500
                ),
                startingPoint: "Bangalore"
            ),
            Trip(
                name: "HYD-004",
                destination: "Kompally Distribution Center", 
                address: "NH-44, Kompally, Hyderabad 500014", 
                eta: "55 mins", 
                distance: "18 km",
                status: .pending,
                vehicleDetails: Vehicle(
                    name: "Tesla",
                    year: 2023,
                    make: "Tesla",
                    model: "Model Y",
                    vin: "5YJYGDEE3MF123456",
                    licensePlate: "TESLA88",
                    vehicleType: .car,
                    color: "White",
                    bodyType: .suv,
                    bodySubtype: "Electric",
                    msrp: 55000.0,
                    pollutionExpiry: Date(),
                    insuranceExpiry: Date(),
                    status: .available,
                    documents: VehicleDocuments()
                ),
                sourceCoordinate: CLLocationCoordinate2D(
                    latitude: 17.3850,
                    longitude: 78.4867
                ),
                destinationCoordinate: CLLocationCoordinate2D(
                    latitude: 17.5434,
                    longitude: 78.4867
                ),
                startingPoint: "Hyderabad"
            )
        ]
        
        let recentDeliveries = [
            DeliveryDetails(
                location: "Bhiwandi Logistics Park",
                date: "Today, 10:30 AM",
                status: "Delivered",
                driver: "Current Driver",
                vehicle: "TRK-005",
                notes: "Delivery completed on time. All packages delivered safely to Bhiwandi warehouse."
            ),
            DeliveryDetails(
                location: "Pune MIDC Warehouse",
                date: "Yesterday, 3:45 PM",
                status: "Delivered",
                driver: "Current Driver",
                vehicle: "TRK-006",
                notes: "Successful delivery to MIDC warehouse. Cargo unloaded at Dock 7."
            ),
            DeliveryDetails(
                location: "Gurgaon Logistics Hub",
                date: "Yesterday, 9:15 AM",
                status: "Delivered",
                driver: "Current Driver",
                vehicle: "TRK-007",
                notes: "Delivery completed to Gurgaon hub. All documentation verified."
            )
        ]
        
        return (currentTrip, upcomingTrips, recentDeliveries)
    }
    
    // Get the current trip data
    func getCurrentTripData() -> Trip {
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
            notes: "Trip \(trip.name) completed successfully. Vehicle: \(trip.vehicleDetails.bodyType) (\(trip.vehicleDetails.licensePlate))"
        )
        
        // Add to recent deliveries
        recentDeliveries.insert(completedDelivery, at: 0)
        
        // Mark the trip as delivered
        var updatedTrip = trip
        updatedTrip.status = .completed
        
        // If this is the current trip, update it
        if currentTrip.id == trip.id {
            currentTrip = updatedTrip
        }
    }
} 
