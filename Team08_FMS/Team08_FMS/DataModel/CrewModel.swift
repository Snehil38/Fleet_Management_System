import Foundation
import SwiftUI

enum Status: String, Codable, Identifiable {
    case available = "Available"
    case busy = "Busy"
    case offDuty = "Off Duty"

    var color: Color {
        switch self {
        case .available: return .green
        case .busy: return .orange
        case .offDuty: return .gray
        }
    }

    var backgroundColor: Color {
        switch self {
        case .available: return .green.opacity(0.2)
        case .busy: return .orange.opacity(0.2)
        case .offDuty: return .gray.opacity(0.2)
        }
    }
    
    var id: String { self.rawValue }
}

enum Specialization: String, CaseIterable, Codable, Identifiable {
    case engineRepair = "Engine Repair"
    case tireMaintenance = "Tire Maintenance"
    case electricalSystems = "Electrical Systems"
    case diagnostics = "Diagnostics"
    case generalMaintenance = "General Maintenance"
    
    var id: String { self.rawValue }
}

enum Certification: String, CaseIterable, Codable, Identifiable {
    case aseCertified = "ASE Certified"
    case dieselMechanic = "Diesel Mechanic"
    case hvacSpecialist = "HVAC Specialist"
    case electricalSystemsCertified = "Electrical Systems Certified"
    case heavyEquipmentTechnician = "Heavy Equipment Technician"
    
    var id: String { self.rawValue }
}

struct FleetManager: Identifiable, Codable {
    let id: UUID
    var name: String
    var profileImage: String
    var email: String
    var phoneNumber: Int
    var createdAt: Date
    var updatedAt: Date?
}

struct Driver: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var profileImage: String?
    var email: String
    var phoneNumber: Int
    var driverLicenseNumber: String
    var driverLicenseExpiry: Date
    var assignedVehicleID: UUID?
    var address: String?
    var salary: Double
    var yearsOfExperience: Int
    var createdAt: Date
    var updatedAt: Date?
    var isDeleted: Bool = false
    var status: Status
}

struct MaintenancePersonnel: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var profileImage: String
    var email: String
    var phoneNumber: Int
    var certifications: Certification
    var yearsOfExperience: Int
    var specialty: Specialization
    var salary: Double
    var address: String?
    var createdAt: Date
    var updatedAt: Date?
    var isDeleted: Bool = false
    var status: Status
}

protocol CrewMemberProtocol {
    var id: UUID { get }
    var name: String { get set }
    var avatar: String { get set } // Renamed from profileImage
    var email: String { get }
    var phoneNumber: Int { get }
    var salary: Double { get }
    var status: Status { get set }
}

extension Driver: CrewMemberProtocol {
    var avatar: String {
        get { profileImage ?? "" } // Return a default value if nil
        set { profileImage = newValue }
    }
}

extension MaintenancePersonnel: CrewMemberProtocol {
    var avatar: String {
        get { profileImage }
        set { profileImage = newValue }
    }
}
