//import SwiftUI
//import Combine
//
//class CrewDataManager: ObservableObject {
//    @Published var drivers: [CrewMember] = []
//    @Published var maintenancePersonnel: [CrewMember] = []
//
//    init() {
//        // Initialize with sample data
//        loadSampleData()
//    }
//    
//    func loadSampleData() {
//        drivers = [
//            CrewMember(
//                id: "DR-2025",
//                name: "John Doe",
//                avatar: "JD",
//                role: "Driver",
//                status: .available,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Experience", value: "5 years"),
//                    DetailItem(label: "License", value: "Class A CDL"),
//                    DetailItem(label: "Last Active", value: "Today, 10:45 AM"),
//                    DetailItem(label: "Vehicle", value: "None assigned"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            ),
//            CrewMember(
//                id: "DR-1982",
//                name: "Mike Smith",
//                avatar: "MS",
//                role: "Driver",
//                status: .busy,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Experience", value: "3 years"),
//                    DetailItem(label: "License", value: "Class B CDL"),
//                    DetailItem(label: "Vehicle", value: "Truck #103"),
//                    DetailItem(label: "ETA", value: "2:30 PM Today"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            ),
//            CrewMember(
//                id: "DR-2133",
//                name: "Alex Wong",
//                avatar: "AW",
//                role: "Driver",
//                status: .onLeave,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Experience", value: "2 years"),
//                    DetailItem(label: "License", value: "Class A CDL"),
//                    DetailItem(label: "Next Shift", value: "Tomorrow, 8:00 AM"),
//                    DetailItem(label: "Hours This Week", value: "32 / 40"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            )
//        ]
//
//        maintenancePersonnel = [
//            CrewMember(
//                id: "MT-0452",
//                name: "Sarah Johnson",
//                avatar: "SJ",
//                role: "Maintenance",
//                status: .available,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Specialty", value: "Engine Repair"),
//                    DetailItem(label: "Experience", value: "7 years"),
//                    DetailItem(label: "Certification", value: "ASE Master Tech"),
//                    DetailItem(label: "Last Job", value: "Yesterday"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            ),
//            CrewMember(
//                id: "MT-0391",
//                name: "Robert Turner",
//                avatar: "RT",
//                role: "Maintenance",
//                status: .busy,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Specialty", value: "Electrical Systems"),
//                    DetailItem(label: "Current Task", value: "Truck #108 Repair"),
//                    DetailItem(label: "Location", value: "Main Garage"),
//                    DetailItem(label: "ETA Completion", value: "1:15 PM Today"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            ),
//            CrewMember(
//                id: "MT-0512",
//                name: "Elena Hernandez",
//                avatar: "EH",
//                role: "Maintenance",
//                status: .onLeave,
//                salary: 5000.0,
//                details: [
//                    DetailItem(label: "Specialty", value: "Brake Systems"),
//                    DetailItem(label: "Experience", value: "4 years"),
//                    DetailItem(label: "Next Shift", value: "Tomorrow, 9:00 AM"),
//                    DetailItem(label: "Last Job", value: "Yesterday, Bus #24"),
//                    DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
//                ]
//            )
//        ]
//    }
//
//    func addDriver(_ driver: CrewMember) {
//        drivers.append(driver)
//    }
//
//    func addMaintenancePersonnel(_ personnel: CrewMember) {
//        maintenancePersonnel.append(personnel)
//    }
//
//    func calculateTotalPages(for crewType: CrewType, itemsPerPage: Int) -> Int {
//        let count = crewType == .drivers ? drivers.count : maintenancePersonnel.count
//        return max(1, Int(ceil(Double(count) / Double(itemsPerPage))))
//    }
//
//    func getPagedCrew(for crewType: CrewType, page: Int, itemsPerPage: Int) -> [CrewMember] {
//        let allCrew = crewType == .drivers ? drivers : maintenancePersonnel
//
//        let startIndex = (page - 1) * itemsPerPage
//        let endIndex = min(startIndex + itemsPerPage, allCrew.count)
//
//        if startIndex >= allCrew.count {
//            return []
//        }
//
//        return Array(allCrew[startIndex..<endIndex])
//    }
//
//    func updateDriverStatus(_ id: String, status: CrewMember.Status) {
//        if let index = drivers.firstIndex(where: { $0.id == id }) {
//            drivers[index] = CrewMember(
//                id: drivers[index].id,
//                name: drivers[index].name,
//                avatar: drivers[index].avatar,
//                role: drivers[index].role,
//                status: status,
//                salary: 5000.0,
//                details: drivers[index].details
//            )
//        }
//    }
//    
//    func updateMaintenancePersonnelStatus(_ id: String, status: CrewMember.Status) {
//        if let index = maintenancePersonnel.firstIndex(where: { $0.id == id }) {
//            maintenancePersonnel[index] = CrewMember(
//                id: maintenancePersonnel[index].id,
//                name: maintenancePersonnel[index].name,
//                avatar: maintenancePersonnel[index].avatar,
//                role: maintenancePersonnel[index].role,
//                status: maintenancePersonnel[index].status,
//                salary: maintenancePersonnel[index].salary,
//                details: maintenancePersonnel[index].details
//            )
//        }
//    }
//    
//    func deleteDriver(_ id: String) {
//        drivers.removeAll { $0.id == id }
//    }
//    
//    func deleteMaintenancePersonnel(_ id: String) {
//        maintenancePersonnel.removeAll { $0.id == id }
//    }
//
//    func updateDriver(_ id: String, name: String, details: [DetailItem]) {
//        if let index = drivers.firstIndex(where: { $0.id == id }) {
//            let updatedDriver = CrewMember(
//                id: drivers[index].id,
//                name: name,
//                avatar: String(name.prefix(2).uppercased()),
//                role: drivers[index].role,
//                status: drivers[index].status,
//                salary: drivers[index].salary,
//                details: details
//            )
//            drivers[index] = updatedDriver
//        }
//    }
//    
//    func updateMaintenancePersonnel(_ id: String, name: String, details: [DetailItem]) {
//        if let index = maintenancePersonnel.firstIndex(where: { $0.id == id }) {
//            let updatedPersonnel = CrewMember(
//                id: maintenancePersonnel[index].id,
//                name: name,
//                avatar: String(name.prefix(2).uppercased()),
//                role: maintenancePersonnel[index].role,
//                status: maintenancePersonnel[index].status,
//                salary: maintenancePersonnel[index].salary,
//                details: details
//            )
//            maintenancePersonnel[index] = updatedPersonnel
//        }
//    }
//    
//    var totalSalaryExpenses: Double {
//        let driversSalaries = drivers.reduce(0) { $0 + $1.salary }
//        let maintenanceSalaries = maintenancePersonnel.reduce(0) { $0 + $1.salary }
//        return driversSalaries + maintenanceSalaries
//    }
//}
