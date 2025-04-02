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
    let estimated_cost: Double?
    let middle_pickup: String?
    let middle_pickup_latitude: Double?
    let middle_pickup_longitude: Double?
}

// Delivery Details Model
struct DeliveryDetails: Identifiable {
    let id: UUID
    let location: String
    let date: String
    let status: String
    let driver: String
    let vehicle: String
    let notes: String
} 