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
    
    @Published var currentTrip: Trip
    @Published var upcomingTrips: [Trip] = []
    @Published var recentDeliveries: [DeliveryDetails]
    @Published var error: TripError?
    
    private let supabaseController = SupabaseDataController.shared
    
    private init() {
        // Initialize with empty data first
        let (current, _, recent) = Self.getInitialTrips()
        self.currentTrip = current
        self.recentDeliveries = recent
        
        // Fetch initial data
        Task {
            do {
                try await fetchTrips()
            } catch {
                print("Error during initial fetch: \(error)")
                if let tripError = error as? TripError {
                    await MainActor.run {
                        self.error = tripError
                    }
                }
            }
        }
    }
    
    @MainActor
    private func fetchTrips() async throws {
        print("Fetching trips...")
        do {
            // Fetch all non-deleted trips
            let response = try await supabaseController.databaseFrom("trips")
                .select("*")
                .eq("is_deleted", value: false)
                .order("created_at", ascending: false)
                .execute()
            
            print("Raw response data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            let decoder = JSONDecoder()
            
            // Configure date formatter for PostgreSQL timestamp format
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateStr = try container.decode(String.self)
                
                // Try parsing with ISO8601DateFormatter first (handles fractional seconds)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                // First try ISO format with fractional seconds
                if let date = isoFormatter.date(from: dateStr) {
                    return date
                }
                
                // If ISO parsing fails, try other formats
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateStr) {
                        return date
                    }
                }
                
                // If all parsing attempts fail, try removing fractional seconds
                if let dotIndex = dateStr.firstIndex(of: ".") {
                    let truncatedStr = String(dateStr[..<dotIndex])
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: truncatedStr) {
                        return date
                    }
                }
                
                print("Failed to parse date string: \(dateStr)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateStr)")
            }
            
            // Decode trips
            let supabaseTrips: [SupabaseTrip]
            do {
                supabaseTrips = try decoder.decode([SupabaseTrip].self, from: response.data)
                print("Successfully decoded \(supabaseTrips.count) trips")
                
                // Print the first trip for debugging
                if let firstTrip = supabaseTrips.first {
                    print("First trip details:")
                    print("ID: \(firstTrip.id)")
                    print("Destination: \(firstTrip.destination)")
                    print("Status: \(firstTrip.trip_status)")
                    print("Vehicle ID: \(firstTrip.vehicle_id)")
                }
            } catch let decodingError as DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key.stringValue) - \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type) - \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type) - \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error: \(decodingError)")
                }
                throw TripError.decodingError("Failed to decode trips: \(decodingError.localizedDescription)")
            }
            
            // Fetch vehicles for all trips
            var tripsWithVehicles: [Trip] = []
            for supabaseTrip in supabaseTrips {
                do {
                    print("Fetching vehicle for trip \(supabaseTrip.id)")
                    if let vehicle = try await supabaseController.fetchVehicleDetails(vehicleId: supabaseTrip.vehicle_id) {
                        print("Successfully fetched vehicle \(vehicle.id) for trip \(supabaseTrip.id)")
                        let trip = Trip(from: supabaseTrip, vehicle: vehicle)
                        print("Created Trip object: name=\(trip.name), status=\(trip.status), destination=\(trip.destination)")
                        tripsWithVehicles.append(trip)
                    } else {
                        print("Warning: Could not find vehicle for trip \(supabaseTrip.id)")
                    }
                } catch {
                    print("Error fetching vehicle for trip \(supabaseTrip.id): \(error)")
                }
            }
            
            print("Successfully processed \(tripsWithVehicles.count) trips with vehicles")
            
            // Update published properties
            await MainActor.run {
                print("Updating UI with \(tripsWithVehicles.count) trips")
                
                // Find current trip (in progress)
                if let currentTrip = tripsWithVehicles.first(where: { $0.status == .inProgress }) {
                    print("Found current trip: \(currentTrip.name)")
                    self.currentTrip = currentTrip
                } else {
                    print("No current trip found")
                }
                
                // Filter upcoming trips (pending or assigned)
                let upcoming = tripsWithVehicles.filter { $0.status == .pending || $0.status == .assigned }
                print("Found \(upcoming.count) upcoming trips")
                for trip in upcoming {
                    print("Upcoming trip: name=\(trip.name), status=\(trip.status)")
                }
                self.upcomingTrips = upcoming
                
                // Convert completed trips to delivery details
                let completedTrips = tripsWithVehicles.filter { $0.status == .completed }
                print("Found \(completedTrips.count) completed trips")
                self.recentDeliveries = completedTrips.map { trip in
                    DeliveryDetails(
                        location: trip.destination,
                        date: trip.eta,
                        status: "Delivered",
                        driver: "Current Driver",
                        vehicle: trip.vehicleDetails.licensePlate,
                        notes: "Trip completed successfully"
                    )
                }
                
                // Clear any previous errors
                self.error = nil
            }
        } catch {
            print("Error fetching trips: \(error)")
            if let postgrestError = error as? PostgrestError {
                throw TripError.fetchError("Database error: \(postgrestError.message)")
            } else {
                throw TripError.fetchError("Failed to fetch trips: \(error.localizedDescription)")
            }
        }
    }
    
    private static func getInitialTrips() -> (current: Trip, upcoming: [Trip], recent: [DeliveryDetails]) {
        let currentTrip = Trip(
            id: UUID(),
            name: "TRP-001",
            destination: "Nhava Sheva Port Terminal",
            address: "JNPT Port Road, Navi Mumbai, Maharashtra 400707",
            eta: "25 mins",
            distance: "8.5 km",
            status: .inProgress,
            vehicleDetails: Vehicle(name: "Volvo", year: 2004, make: "IDK", model: "CTY", vin: "sadds", licensePlate: "adsd", vehicleType: .truck, color: "White", bodyType: .cargo, bodySubtype: "IDK", msrp: 10.0, pollutionExpiry: Date(), insuranceExpiry: Date(), status: .available, documents: VehicleDocuments()),
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
                id: UUID(),
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
                id: UUID(),
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
                id: UUID(),
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
        return availabilityManager.isAvailable ? upcomingTrips : []
    }
    
    // Add a function to get recentDeliveries data
    func getRecentDeliveries() -> [DeliveryDetails] {
        return recentDeliveries
    }
    
    // Add a function to mark a trip as delivered
    func markTripAsDelivered(trip: Trip) {
        Task {
            do {
                print("Marking trip \(trip.id) as delivered...")
                // Update trip status in Supabase
                try await supabaseController.updateTrip(id: trip.id, status: TripStatus.completed.rawValue)
                
                print("Successfully marked trip as delivered")
                // Fetch updated data
                try await fetchTrips()
            } catch {
                print("Error marking trip as delivered: \(error)")
                await MainActor.run {
                    self.error = .updateError("Failed to mark trip as delivered: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add a function to manually refresh trips
    @MainActor
    func refreshTrips() async throws {
        print("Manual refresh triggered")
        try await fetchTrips()
    }
} 
