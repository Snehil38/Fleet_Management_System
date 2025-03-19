//
//  DataController.swift
//  Team08_FMS
//
//  Created by Swarn Singh Chauhan on 19/03/25.
//

import Foundation

class FleetDataController {
    
    static let shared = FleetDataController()
    
    var fleetManagers: [FleetManager] = []
    var drivers: [Driver] = []
    var maintenancePersonnel: [MaintenancePersonnel] = []
    
    private init() {
        loadFleetManagers()
        loadDrivers()
        loadMaintenancePersonnel()
    }
    
    // Populate sample Fleet Manager data
    private func loadFleetManagers() {
        fleetManagers = [
            FleetManager(
                employeeID: UUID(),
                name: "Alice Johnson",
                profileImage: "fleetManager1",
                email: "alice.johnson@example.com",
                phoneNumber: "555-000-1111",
                department: "Operations",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "AJ"
            ),
            FleetManager(
                employeeID: UUID(),
                name: "Bob Williams",
                profileImage: "fleetManager2",
                email: "bob.williams@example.com",
                phoneNumber: "555-000-2222",
                department: "Logistics",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "BW"
            )
        ]
    }
    
    // Populate sample Driver data
    private func loadDrivers() {
        drivers = [
            Driver(
                employeeID: UUID(),
                name: "Charlie Davis",
                profileImage: "driver1",
                email: "charlie.davis@example.com",
                phoneNumber: "555-111-2222",
                driverLicenseNumber: "DL123456",
                driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
                assignedVehicleID: "VH001",
                driverRating: 4.5,
                address: "123 Main Street",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "CD"
            ),
            Driver(
                employeeID: UUID(),
                name: "Diana Prince",
                profileImage: "driver2",
                email: "diana.prince@example.com",
                phoneNumber: "555-333-4444",
                driverLicenseNumber: "DL654321",
                driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date(),
                assignedVehicleID: nil,
                driverRating: 4.8,
                address: "456 Elm Street",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "DP"
            )
        ]
    }
    
    // Populate sample Maintenance Personnel data
    private func loadMaintenancePersonnel() {
        maintenancePersonnel = [
            MaintenancePersonnel(
                name: "Edward King",
                profileImage: "maintenance1",
                email: "edward.king@example.com",
                phoneNumber: "555-555-6666",
                certifications: ["Engine Repair", "Electrical Systems"],
                yearsOfExperience: 6,
                specialty: "Engine Repair",
                address: "789 Oak Avenue",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "EK"
            ),
            MaintenancePersonnel(
                name: "Fiona Queen",
                profileImage: "maintenance2",
                email: "fiona.queen@example.com",
                phoneNumber: "555-777-8888",
                certifications: ["Brake Systems"],
                yearsOfExperience: 4,
                specialty: "Brake Systems",
                address: "321 Pine Road",
                createdAt: Date(),
                updatedAt: Date(),
                avatar: "FQ"
            )
        ]
    }
}
