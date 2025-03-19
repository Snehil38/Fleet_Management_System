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
            name: "MUM-001",
            destination: "Nhava Sheva Port Terminal",
            address: "JNPT Port Road, Navi Mumbai, Maharashtra 400707",
            eta: "25 mins",
            distance: "8.5 km",
            status: .current,
            vehicleDetails: VehicleDetails(
                number: "TRK-001",
                type: "Container Truck",
                licensePlate: "MH-43-AB-1234",
                capacity: "40 tons"
            ),
            sourceCoordinate: CLLocationCoordinate2D(
                latitude: 19.0178,
                longitude: 72.8478
            ),
            destinationCoordinate: CLLocationCoordinate2D(
                latitude: 18.9490,
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
                status: .upcoming,
                vehicleDetails: VehicleDetails(
                    number: "TRK-002",
                    type: "Multi-axle Truck",
                    licensePlate: "DL-01-CD-5678",
                    capacity: "35 tons"
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
                status: .upcoming,
                vehicleDetails: VehicleDetails(
                    number: "TRK-003",
                    type: "Container Truck",
                    licensePlate: "KA-03-EF-9012",
                    capacity: "30 tons"
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
                status: .upcoming,
                vehicleDetails: VehicleDetails(
                    number: "TRK-004",
                    type: "Box Truck",
                    licensePlate: "TS-07-GH-3456",
                    capacity: "25 tons"
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
            vehicle: trip.vehicleDetails.number,
            notes: "Trip \(trip.name) completed successfully. Vehicle: \(trip.vehicleDetails.type) (\(trip.vehicleDetails.licensePlate))"
        )
        
        // Add to recent deliveries
        recentDeliveries.insert(completedDelivery, at: 0)
        
        // Mark the trip as delivered
        var updatedTrip = trip
        updatedTrip.status = .delivered
        
        // If this is the current trip, update it
        if currentTrip.id == trip.id {
            currentTrip = updatedTrip
        }
    }
} 
