import Foundation

struct FleetManager {
    let employeeID: UUID
    var name: String
    var profileImage: String
    var email: String
    var phoneNumber: String
    var department: String
    var createdAt: Date
    var updatedAt: Date
    let avatar:String?
}

struct Driver {
    let employeeID: UUID
    var name: String
    var profileImage: String
    var email: String
    var phoneNumber: String
    var driverLicenseNumber: String
    var driverLicenseExpiry: Date
    var assignedVehicleID: String?
    var driverRating: Double?
    var address: String?             
    var createdAt: Date
    var updatedAt: Date?
    let avatar:String?
}

struct MaintenancePersonnel {
    let employeeID: UUID = UUID()
    var name: String
    var profileImage: String
    var email: String
    var phoneNumber: String
    var certifications: [String]?
    var yearsOfExperience: Int
    var specialty: String
    var address: String?              
    var createdAt: Date = Date()
    var updatedAt: Date?
    let avatar:String?
}
