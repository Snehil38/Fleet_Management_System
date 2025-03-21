import Foundation

struct DeliveryDetails: Identifiable, Codable {
    let id: UUID
    let location: String
    let date: String
    let status: String
    let driver: String
    let vehicle: String
    let notes: String
    
    init(location: String, date: String, status: String, driver: String, vehicle: String, notes: String) {
        self.id = UUID()
        self.location = location
        self.date = date
        self.status = status
        self.driver = driver
        self.vehicle = vehicle
        self.notes = notes
    }
} 