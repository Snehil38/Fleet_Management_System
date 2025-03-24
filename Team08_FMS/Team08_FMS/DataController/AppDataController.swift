//
//  AppDataController.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import Foundation

class AppDataController {
    static let shared = AppDataController()
    
    private init() {
        
    }
    
    func randomPasswordGenerator(length: Int) -> String {
        let character = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        return String((0..<length).map { _ in character.randomElement()! })
    }
    
    func getStatusString(status: Status) -> String {
        switch status {
        case .available:
            return "Available"
        case .busy:
            return "Busy"
        case .offDuty:
            return "Off Duty"
        }
    }
    
    func getSpecialityString(speciality: Specialization) -> String {
        switch speciality {
        case .engineRepair:
            return "Engine Repair"
        case .tireMaintenance:
            return "Tire Maintenance"
        case .electricalSystems:
            return "Electrical Systems"
        case .diagnostics:
            return "Diagnostics"
        case .generalMaintenance:
            return "General Maintenance"
        }
    }
    
    func getCertificationString(certification: Certification) -> String {
        switch certification {
        case .aseCertified:
            return "ASE Certified"
        case .dieselMechanic:
            return "Diesel Mechanic"
        case .hvacSpecialist:
            return "HVAC Specialist"
        case .electricalSystemsCertified:
            return "Electrical Systems Certified"
        case .heavyEquipmentTechnician:
            return "Heavy Equipment Technician"
        }
    }
}
