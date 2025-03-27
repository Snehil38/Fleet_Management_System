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

struct SafetyCheck: Identifiable, Codable, Equatable {
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

struct MaintenanceServiceRequest: Identifiable, Codable, Equatable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let priority: ServiceRequestPriority
    let date: Date
    let dueDate: Date
    var status: ServiceRequestStatus
    var notes: String
    let issueType: String?
    var safetyChecks: [SafetyCheck]
    var expenses: [Expense]
    var totalCost: Double
    var startDate: Date?
    var completionDate: Date?
    
    init(vehicleId: UUID, vehicleName: String, serviceType: ServiceType, description: String, priority: ServiceRequestPriority, date: Date, dueDate: Date, status: ServiceRequestStatus, notes: String, issueType: String? = nil) {
        self.id = UUID()
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.serviceType = serviceType
        self.description = description
        self.priority = priority
        self.date = date
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.issueType = issueType
        self.safetyChecks = []
        self.expenses = []
        self.totalCost = 0.0
    }
    
    static func == (lhs: MaintenanceServiceRequest, rhs: MaintenanceServiceRequest) -> Bool {
        lhs.id == rhs.id &&
        lhs.vehicleId == rhs.vehicleId &&
        lhs.vehicleName == rhs.vehicleName &&
        lhs.serviceType == rhs.serviceType &&
        lhs.description == rhs.description &&
        lhs.priority == rhs.priority &&
        lhs.date == rhs.date &&
        lhs.dueDate == rhs.dueDate &&
        lhs.status == rhs.status &&
        lhs.notes == rhs.notes &&
        lhs.issueType == rhs.issueType &&
        lhs.safetyChecks == rhs.safetyChecks &&
        lhs.expenses == rhs.expenses &&
        lhs.totalCost == rhs.totalCost &&
        lhs.startDate == rhs.startDate &&
        lhs.completionDate == rhs.completionDate
    }
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    let description: String
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    
    init(description: String, amount: Double, date: Date, category: ExpenseCategory) {
        self.id = UUID()
        self.description = description
        self.amount = amount
        self.date = date
        self.category = category
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case parts = "Parts"
    case labor = "Labor"
    case supplies = "Supplies"
    case other = "Other"
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
