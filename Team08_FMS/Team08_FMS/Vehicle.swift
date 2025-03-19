//
//  Vehicle.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import Foundation

enum VehicleStatus: String, Codable, CaseIterable {
    case idle = "Idle"
    case allotted = "Alloted"
    case maintenance = "Maintenance"
}

enum VehicleType: String, Codable, CaseIterable {
    case car = "Car"
    case truck = "Truck"
    case van = "Van"
    case bus = "Bus"
}

enum BodyType: String, Codable, CaseIterable {
    case sedan = "Sedan"
    case suv = "SUV"
    case pickup = "Pickup"
    case cargo = "Cargo"
}

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

    init(id: UUID = UUID(), name: String = "", year: Int = 0, make: String = "", model: String = "",
         vin: String = "", licensePlate: String = "", vehicleType: VehicleType = .car,
         color: String = "", bodyType: BodyType = .sedan, bodySubtype: String = "",
         msrp: Double = 0.0, pollutionExpiry: Date = Date(), insuranceExpiry: Date = Date(),
         status: VehicleStatus = .idle, driverId: UUID? = nil, documents: VehicleDocuments = VehicleDocuments()) {
        self.id = id
        self.name = name
        self.year = year
        self.make = make
        self.model = model
        self.vin = vin
        self.licensePlate = licensePlate
        self.vehicleType = vehicleType
        self.color = color
        self.bodyType = bodyType
        self.bodySubtype = bodySubtype
        self.msrp = msrp
        self.pollutionExpiry = pollutionExpiry
        self.insuranceExpiry = insuranceExpiry
        self.status = status
        self.driverId = driverId
        self.documents = documents
    }
}

struct VehicleDocuments: Codable {
    var pollutionCertificate: Data?
    var rc: Data?
    var insurance: Data?
}
