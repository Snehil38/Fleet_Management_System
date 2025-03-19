//
//  AppDataModel.swift
//  Team08_FMS
//
//  Created by Swarn Singh Chauhan on 19/03/25.
//

import Foundation
import Foundation

// MARK: - App Data Model
struct Vehicle: Identifiable, Codable {
    var id: UUID
    var name: String
    var year: Int
    var make: String
    var model: String
    var vin: String
    var licensePlate: String
    var vehicleType: VehicleType
    var color: String
    var bodyType: BodyType
    var bodySubtype: String
    var msrp: Double
    var pollutionExpiry: Date
    var insuranceExpiry: Date
    var status: VehicleStatus
    var driverId: UUID?  // Optional because vehicle might not be assigned to any driver
    var documents: VehicleDocuments
}

struct AppDataModel {
    // Users of the fleet management system
    //var users: [User] = []
    var drivers:[Driver] = []
    var maintenancePersonnel:[MaintenancePersonnel] = []
    
    // Vehicles in the fleet
    var vehicles: [Vehicle] = []
    
    // Trips or assignments
    var trips: [Trip] = []
    
    // Maintenance records for vehicles
    var maintenanceRecords: [MaintenanceRecord] = []
    
    // Notifications for various events
    var notifications: [NotificationItem] = []
    
    // Global settings for the app
    var settings: AppSettings = AppSettings(defaultOperatingHours: "08:00 - 18:00", supportContact: "support@example.com")
}

// MARK: - Supporting Data Models
enum VehicleStatus: String, Codable {
    case available
    case inService
    case underMaintenance
    case decommissioned

    static let allValues: [VehicleStatus] = [
        .available,
        .inService,
        .underMaintenance,
        .decommissioned
    ]
}

struct Route: Codable {
    var startLocation: String
    var endLocation: String
    var waypoints: [String]?
}

enum MaintenanceStatus: String, Codable {
    case scheduled
    case inProgress
    case completed
}

struct MaintenanceRecord: Identifiable, Codable {
    var id: String
    var vehicleID: String
    var personnelID: String
    var date: Date
    var description: String
    var status: MaintenanceStatus
}

enum NotificationType: String, Codable {
    case maintenanceDue
    case tripUpdate
    case alert
    case info
}

struct NotificationItem: Identifiable, Codable {
    var id: String
    var title: String
    var message: String
    var date: Date
    var type: NotificationType
}

struct AppSettings: Codable {
    var defaultOperatingHours: String
    var supportContact: String
}

struct ServiceRequest: Identifiable {
    let id = UUID()
    let vehicleId: String
    let vehicleName: String
    let issueType: String
    let description: String
    let priority: String
    let date: Date
    let status: String
}

enum VehicleType: String, Codable, CaseIterable {
    case truck = "Truck"
    case van = "Van"
}

enum BodyType: String, Codable, CaseIterable {
    case pickup = "Pickup"
    case cargo = "Cargo"
}

struct VehicleDocuments: Codable {
    var pollutionCertificate: Data?
    var rc: Data?
    var insurance: Data?
}
