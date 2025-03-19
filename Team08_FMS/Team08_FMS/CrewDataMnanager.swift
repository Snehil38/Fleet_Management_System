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
                details: [
                    DetailItem(label: "Experience", value: "5 years"),
                    DetailItem(label: "License", value: "Class A CDL"),
                    DetailItem(label: "Last Active", value: "Today, 10:45 AM"),
                    DetailItem(label: "Vehicle", value: "None assigned")
                ]
            ),
            CrewMember(
                id: "DR-1982",
                name: "Mike Smith",
                avatar: "MS",
                role: "Driver",
                status: .busy,
                details: [
                    DetailItem(label: "Experience", value: "3 years"),
                    DetailItem(label: "License", value: "Class B CDL"),
                    DetailItem(label: "Vehicle", value: "Truck #103"),
                    DetailItem(label: "ETA", value: "2:30 PM Today")
                ]
            ),
            CrewMember(
                id: "DR-2133",
                name: "Alex Wong",
                avatar: "AW",
                role: "Driver",
                status: .offline,
                details: [
                    DetailItem(label: "Experience", value: "2 years"),
                    DetailItem(label: "License", value: "Class A CDL"),
                    DetailItem(label: "Next Shift", value: "Tomorrow, 8:00 AM"),
                    DetailItem(label: "Hours This Week", value: "32 / 40")
                ]
            )
        ]

        maintenancePersonnel = [
            CrewMember(
                id: "MT-0452",
                name: "Sarah Johnson",
                avatar: "SJ",
                role: "Maintenance",
                status: .available,
                details: [
                    DetailItem(label: "Specialty", value: "Engine Repair"),
                    DetailItem(label: "Experience", value: "7 years"),
                    DetailItem(label: "Certification", value: "ASE Master Tech"),
                    DetailItem(label: "Last Job", value: "Yesterday")
                ]
            ),
            CrewMember(
                id: "MT-0391",
                name: "Robert Turner",
                avatar: "RT",
                role: "Maintenance",
                status: .busy,
                details: [
                    DetailItem(label: "Specialty", value: "Electrical Systems"),
                    DetailItem(label: "Current Task", value: "Truck #108 Repair"),
                    DetailItem(label: "Location", value: "Main Garage"),
                    DetailItem(label: "ETA Completion", value: "1:15 PM Today")
                ]
            ),
            CrewMember(
                id: "MT-0512",
                name: "Elena Hernandez",
                avatar: "EH",
                role: "Maintenance",
                status: .offline,
                details: [
                    DetailItem(label: "Specialty", value: "Brake Systems"),
                    DetailItem(label: "Experience", value: "4 years"),
                    DetailItem(label: "Next Shift", value: "Tomorrow, 9:00 AM"),
                    DetailItem(label: "Last Job", value: "Yesterday, Bus #24")
                ]
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
}
