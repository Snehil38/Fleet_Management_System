import Foundation

enum ServiceType: String, CaseIterable, Codable {
    case routine = "Routine"
    case repair = "Repair"
    case inspection = "Inspection"
    case emergency = "Emergency"
}

enum ServiceRequestStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case assigned = "Assigned"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

enum ServiceRequestPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
}

struct SafetyCheck: Identifiable, Codable {
    let id: UUID
    let item: String
    var isChecked: Bool
    var notes: String
    
    init(id: UUID = UUID(), item: String, isChecked: Bool = false, notes: String = "") {
        self.id = id
        self.item = item
        self.isChecked = isChecked
        self.notes = notes
    }
}

struct MaintenanceServiceRequest: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let priority: ServiceRequestPriority
    let date: Date
    let dueDate: Date
    var status: ServiceRequestStatus
    let notes: String
    let issueType: String?
    var safetyChecks: [SafetyCheck]
}

struct ServiceHistory: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let date: Date
    let completionDate: Date
    let notes: String
    let safetyChecks: [SafetyCheck]
} 
