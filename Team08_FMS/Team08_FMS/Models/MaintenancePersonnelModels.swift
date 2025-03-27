import Foundation

// Local data models for maintenance personnel
struct MaintenancePersonnelServiceHistory: Identifiable {
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

struct MaintenancePersonnelRoutineSchedule: Identifiable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let interval: Int // in days
    let lastServiceDate: Date
    let nextServiceDate: Date
    let notes: String
}

// Local data store
class MaintenancePersonnelDataStore: ObservableObject {
    @Published var serviceRequests: [MaintenanceServiceRequest] = []
    @Published var serviceHistory: [MaintenancePersonnelServiceHistory] = []
    @Published var routineSchedules: [MaintenancePersonnelRoutineSchedule] = []
    @Published var inspectionRequests: [InspectionRequest] = []
    
    init() {
        // Initialize with sample data
        loadSampleData()
    }
    
    private func loadSampleData() {
        // Sample service requests
        serviceRequests = [
            MaintenanceServiceRequest(
                vehicleId: UUID(),
                vehicleName: "Truck 001",
                serviceType: .routine,
                description: "Regular maintenance check",
                priority: .medium,
                date: Date(),
                dueDate: Date().addingTimeInterval(86400 * 7),
                status: .pending,
                notes: "Regular maintenance required",
                issueType: nil
            ),
            MaintenanceServiceRequest(
                vehicleId: UUID(),
                vehicleName: "Van 002",
                serviceType: .repair,
                description: "Brake system check",
                priority: .high,
                date: Date(),
                dueDate: Date().addingTimeInterval(86400 * 2),
                status: .inProgress,
                notes: "Urgent brake system inspection needed",
                issueType: "Brake System"
            )
        ]
        
        // Sample inspection requests
        inspectionRequests = [
            InspectionRequest(
                id: UUID(),
                vehicleId: UUID(),
                vehicleName: "Truck 003",
                driverId: UUID(),
                driverName: "John Doe",
                type: .preTrip,
                description: "Pre-trip inspection required",
                date: Date(),
                status: .pending,
                issues: [
                    InspectionIssue(
                        id: UUID(),
                        description: "Low tire pressure",
                        severity: .medium
                    ),
                    InspectionIssue(
                        id: UUID(),
                        description: "Check engine light on",
                        severity: .high
                    )
                ],
                notes: "Driver reported multiple issues"
            ),
            InspectionRequest(
                id: UUID(),
                vehicleId: UUID(),
                vehicleName: "Van 004",
                driverId: UUID(),
                driverName: "Jane Smith",
                type: .postTrip,
                description: "Post-trip inspection completed",
                date: Date(),
                status: .pending,
                issues: [
                    InspectionIssue(
                        id: UUID(),
                        description: "Brake noise",
                        severity: .high
                    )
                ],
                notes: "Driver reported brake issues"
            )
        ]
        
        // Sample service history
        serviceHistory = [
            MaintenancePersonnelServiceHistory(
                id: UUID(),
                vehicleId: UUID(),
                vehicleName: "Truck 003",
                serviceType: .routine,
                description: "Oil change and inspection",
                date: Date().addingTimeInterval(-86400 * 30),
                completionDate: Date().addingTimeInterval(-86400 * 29),
                notes: "Completed successfully",
                safetyChecks: []
            )
        ]
        
        // Sample routine schedules
        routineSchedules = [
            MaintenancePersonnelRoutineSchedule(
                id: UUID(),
                vehicleId: UUID(),
                vehicleName: "Truck 001",
                serviceType: .routine,
                interval: 30,
                lastServiceDate: Date().addingTimeInterval(-86400 * 15),
                nextServiceDate: Date().addingTimeInterval(86400 * 15),
                notes: "Monthly maintenance"
            )
        ]
    }
    
    // MARK: - Service Request Methods
    func updateServiceRequestStatus(_ request: MaintenanceServiceRequest, newStatus: ServiceRequestStatus) {
        if let index = serviceRequests.firstIndex(where: { $0.id == request.id }) {
            var updatedRequest = request
            updatedRequest.status = newStatus
            
            switch newStatus {
            case .inProgress:
                updatedRequest.startDate = Date()
            case .completed:
                updatedRequest.completionDate = Date()
            default:
                break
            }
            
            serviceRequests[index] = updatedRequest
        }
    }
    
    func addExpense(to request: MaintenanceServiceRequest, expense: Expense) {
        if let index = serviceRequests.firstIndex(where: { $0.id == request.id }) {
            var updatedRequest = request
            updatedRequest.expenses.append(expense)
            updatedRequest.totalCost = updatedRequest.expenses.reduce(0) { $0 + $1.amount }
            serviceRequests[index] = updatedRequest
        }
    }
    
    func updateSafetyChecks(for request: MaintenanceServiceRequest, checks: [SafetyCheck]) {
        if let index = serviceRequests.firstIndex(where: { $0.id == request.id }) {
            var updatedRequest = request
            updatedRequest.safetyChecks = checks
            serviceRequests[index] = updatedRequest
        }
    }
    
    // MARK: - Service History Methods
    func addToServiceHistory(_ request: MaintenanceServiceRequest) {
        let history = MaintenancePersonnelServiceHistory(
            id: UUID(),
            vehicleId: request.vehicleId,
            vehicleName: request.vehicleName,
            serviceType: request.serviceType,
            description: request.description,
            date: request.date,
            completionDate: Date(),
            notes: request.notes,
            safetyChecks: request.safetyChecks
        )
        serviceHistory.append(history)
    }
    
    // MARK: - Routine Schedule Methods
    func addRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) {
        routineSchedules.append(schedule)
    }
    
    func updateRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) {
        if let index = routineSchedules.firstIndex(where: { $0.id == schedule.id }) {
            routineSchedules[index] = schedule
        }
    }
    
    func deleteRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) {
        routineSchedules.removeAll { $0.id == schedule.id }
    }
} 
