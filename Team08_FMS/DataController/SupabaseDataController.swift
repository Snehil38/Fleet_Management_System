struct TripUpdate: Encodable {
    let trip_status: String
    let has_completed_pre_trip: Bool
    let has_completed_post_trip: Bool
    let end_time: String?
    let updated_at: String
    let driver_id: String?
    
    init(trip: Trip) {
        self.trip_status = trip.tripStatus.rawValue.lowercased()
        self.has_completed_pre_trip = trip.hasCompletedPreTrip
        self.has_completed_post_trip = trip.hasCompletedPostTrip
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        self.end_time = trip.endTime.map { dateFormatter.string(from: $0) }
        self.updated_at = dateFormatter.string(from: Date())
        self.driver_id = trip.driverId?.uuidString
    }
} 