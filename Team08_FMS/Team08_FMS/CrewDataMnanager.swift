import SwiftUI
import Combine

class CrewDataManager: ObservableObject {
    @Published var drivers: [CrewMember] = []
    @Published var maintenancePersonnel: [CrewMember] = []

    init() {
        // Initialize with sample data
        loadSampleData()
    }
    
    func loadSampleData() {
        drivers = [
            CrewMember(
                id: "DR-2025",
                name: "John Doe",
                avatar: "JD",
                role: "Driver",
                status: .available,
                salary: 5000.00
            ),
            CrewMember(
                id: "DR-1982",
                name: "Mike Smith",
                avatar: "MS",
                role: "Driver",
                status: .busy,
                salary: 5200.00
            ),
            CrewMember(
                id: "DR-2133",
                name: "Alex Wong",
                avatar: "AW",
                role: "Driver",
                status: .offline,
                salary: 5000.00
            )
        ]

        maintenancePersonnel = [
            CrewMember(
                id: "MT-0452",
                name: "Sarah Johnson",
                avatar: "SJ",
                role: "Maintenance",
                status: .available,
                salary: 4800.00
            ),
            CrewMember(
                id: "MT-0391",
                name: "Robert Turner",
                avatar: "RT",
                role: "Maintenance",
                status: .busy,
                salary: 5000.00
            ),
            CrewMember(
                id: "MT-0512",
                name: "Elena Hernandez",
                avatar: "EH",
                role: "Maintenance",
                status: .offline,
                salary: 4900.00
            )
        ]
    }

    func addDriver(_ driver: CrewMember) {
        drivers.append(driver)
    }

    func addMaintenancePersonnel(_ personnel: CrewMember) {
        maintenancePersonnel.append(personnel)
    }

    func calculateTotalPages(for crewType: CrewType, itemsPerPage: Int) -> Int {
        let count = crewType == .drivers ? drivers.count : maintenancePersonnel.count
        return max(1, Int(ceil(Double(count) / Double(itemsPerPage))))
    }

    func getPagedCrew(for crewType: CrewType, page: Int, itemsPerPage: Int) -> [CrewMember] {
        let allCrew = crewType == .drivers ? drivers : maintenancePersonnel

        let startIndex = (page - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allCrew.count)

        if startIndex >= allCrew.count {
            return []
        }

        return Array(allCrew[startIndex..<endIndex])
    }

    func updateDriverStatus(_ id: String, status: CrewMember.Status) {
        if let index = drivers.firstIndex(where: { $0.id == id }) {
            var updatedDriver = drivers[index]
            updatedDriver.status = status
            drivers[index] = updatedDriver
        }
    }
    
    func updateMaintenancePersonnelStatus(_ id: String, status: CrewMember.Status) {
        if let index = maintenancePersonnel.firstIndex(where: { $0.id == id }) {
            var updatedPersonnel = maintenancePersonnel[index]
            updatedPersonnel.status = status
            maintenancePersonnel[index] = updatedPersonnel
        }
    }
    
    func deleteDriver(_ id: String) {
        drivers.removeAll { $0.id == id }
    }
    
    func deleteMaintenancePersonnel(_ id: String) {
        maintenancePersonnel.removeAll { $0.id == id }
    }

    func updateDriver(_ updatedDriver: CrewMember) {
        if let index = drivers.firstIndex(where: { $0.id == updatedDriver.id }) {
            let driver = CrewMember(
                id: updatedDriver.id,
                name: updatedDriver.name,
                avatar: updatedDriver.avatar,
                role: updatedDriver.role,
                status: updatedDriver.status,
                salary: updatedDriver.salary
            )
            drivers[index] = driver
        }
    }
    
    func updateMaintenancePersonnel(_ updatedPersonnel: CrewMember) {
        if let index = maintenancePersonnel.firstIndex(where: { $0.id == updatedPersonnel.id }) {
            let personnel = CrewMember(
                id: updatedPersonnel.id,
                name: updatedPersonnel.name,
                avatar: updatedPersonnel.avatar,
                role: updatedPersonnel.role,
                status: updatedPersonnel.status,
                salary: updatedPersonnel.salary
            )
            maintenancePersonnel[index] = personnel
        }
    }

    var totalSalaryExpenses: Double {
        let driversSalaries = drivers.reduce(0) { $0 + $1.salary }
        let maintenanceSalaries = maintenancePersonnel.reduce(0) { $0 + $1.salary }
        return driversSalaries + maintenanceSalaries
    }
}
