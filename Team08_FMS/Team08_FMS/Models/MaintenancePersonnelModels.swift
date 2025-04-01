import Foundation

// Local data models for maintenance personnel
struct MaintenancePersonnelServiceHistory: Identifiable, Codable {
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

struct MaintenancePersonnelRoutineSchedule: Identifiable, Codable {
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
import Foundation
import Supabase
import Combine

class MaintenancePersonnelDataStore: ObservableObject {
    @Published var serviceRequests: [MaintenanceServiceRequest] = []
    @Published var serviceHistory: [MaintenancePersonnelServiceHistory] = []
    @Published var routineSchedules: [MaintenancePersonnelRoutineSchedule] = []
    @Published var inspectionRequests: [InspectionRequest] = []  // Assuming these remain local or handled separately
    
    init() {
        // Load data from Supabase when the data store is created
        Task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        do {
            // Fetch data from Supabase via the shared data controller
            let fetchedServiceHistory = try await SupabaseDataController.shared.fetchServiceHistory()
            let fetchedRoutineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
            let fetchedServiceRequests = try await SupabaseDataController.shared.fetchServiceRequests()

            // Capture self weakly to avoid strong reference cycles
            await MainActor.run {
                self.serviceHistory = fetchedServiceHistory
                self.routineSchedules = fetchedRoutineSchedules
                self.serviceRequests = fetchedServiceRequests
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    // MARK: - Service History Methods
    func addToServiceHistory(from request: MaintenanceServiceRequest) async {
        // Create a new service history record based on the service request
        let newHistory = MaintenancePersonnelServiceHistory(
            id: UUID(),
            vehicleId: request.vehicleId,
            vehicleName: request.vehicleName,
            serviceType: request.serviceType,
            description: request.description,
            date: request.date,
            completionDate: Date(),  // Assuming completionDate is set to now
            notes: request.notes,
            safetyChecks: request.safetyChecks
        )
        
        do {
            try await SupabaseDataController.shared.insertServiceHistory(history: newHistory)
            // Refresh the local service history data after insertion
            serviceHistory = try await SupabaseDataController.shared.fetchServiceHistory()
        } catch {
            print("Error adding service history: \(error)")
        }
    }
    
    func addServiceHistory(_ history: MaintenancePersonnelServiceHistory) async {
        do {
            try await SupabaseDataController.shared.insertServiceHistory(history: history)
            serviceHistory = try await SupabaseDataController.shared.fetchServiceHistory()
        } catch {
            print("Error inserting service history: \(error)")
        }
    }
    
    // MARK: - Routine Schedule Methods
    
    func addRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        do {
            try await SupabaseDataController.shared.insertRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error inserting routine schedule: \(error)")
        }
    }
    
    func updateRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        // This assumes you have an update function in your SupabaseDataController
        do {
            // Update on the backend and then refresh the local copy
            try await SupabaseDataController.shared.insertRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error updating routine schedule: \(error)")
        }
    }
    
    func deleteRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        // You would need to add a delete function in your SupabaseDataController
        do {
            try await SupabaseDataController.shared.deleteRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error deleting routine schedule: \(error)")
        }
    }
    
    // MARK: - Service Request Methods
    
    func addServiceRequest(_ request: MaintenanceServiceRequest) async {
        do {
            try await SupabaseDataController.shared.insertServiceRequest(request: request)
            serviceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
        } catch {
            print("Error inserting service request: \(error)")
        }
    }
    
    func updateServiceRequestStatus(_ request: MaintenanceServiceRequest, newStatus: ServiceRequestStatus) async {
        if let index = serviceRequests.firstIndex(where: { $0.id == request.id }) {
            var updatedRequest = request
            updatedRequest.status = newStatus
            
            // Handle specific status changes (e.g., start date for "In Progress" and completion date for "Completed")
            switch newStatus {
            case .inProgress:
                updatedRequest.startDate = Date()
            case .completed:
                updatedRequest.completionDate = Date()
            default:
                break
            }
            
            // Call SupabaseDataController to update the service request in the database
            do {
                let updateSuccess = try await SupabaseDataController.shared.updateServiceRequestStatus(serviceRequestId: updatedRequest.id, newStatus: newStatus)
                
                if updateSuccess {
                    // After successful update, update the local serviceRequests array
                    serviceRequests[index] = updatedRequest
                    print("Service request status updated successfully.")
                } else {
                    print("Failed to update service request status in Supabase.")
                }
            } catch {
                print("Error updating service request status: \(error)")
            }
        }
    }

    func addExpense(to request: MaintenanceServiceRequest, expense: Expense) async {
        do {
            try await SupabaseDataController.shared.insertExpense(expense: expense)
            serviceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
        } catch {
            print("Error inserting expense: \(error)")
        }
    }
    
    func updateSafetyChecks(for request: MaintenanceServiceRequest, checks: [SafetyCheck]) async {
        do {
            // For simplicity, insert all provided safety checks. In a real app you might want to update or delete as needed.
            for check in checks {
                try await SupabaseDataController.shared.insertSafetyCheck(check: check)
            }
            serviceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
        } catch {
            print("Error updating safety checks: \(error)")
        }
    }
}
