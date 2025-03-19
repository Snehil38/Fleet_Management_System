import SwiftUI
import Foundation

// MARK: - Main CrewMember Structure
struct CrewMember: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let role: String
    var status: Status
    
    let salary: Double
    
    // MARK: - Status Enum
    enum Status: String {
        case available = "Available"
        case busy = "Busy"
        case offline = "Offline"
        
        var color: Color {
            switch self {
            case .available: return .green
            case .busy: return .yellow
            case .offline: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .available: return .green.opacity(0.2)
            case .busy: return .yellow.opacity(0.2)
            case .offline: return .red.opacity(0.2)
            }
        }
    }
    
    // MARK: - DetailItem Structure
    struct DetailItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }
    
    // MARK: - Computed Properties
    var details: [DetailItem] {
        var items = [DetailItem]()
        
        switch role {
        case "Driver":
            items = [
                DetailItem(label: "Experience", value: "5 years"),
                DetailItem(label: "License", value: "Class A CDL"),
                DetailItem(label: "Phone", value: "+1 (555) 123-4567"),
                DetailItem(label: "Email", value: "driver@example.com")
            ]
        case "Maintenance":
            items = [
                DetailItem(label: "Specialty", value: "Engine Repair"),
                DetailItem(label: "Experience", value: "8 years"),
                DetailItem(label: "Phone", value: "+1 (555) 987-6543"),
                DetailItem(label: "Email", value: "maintenance@example.com")
            ]
        default:
            break
        }
        
        items.append(DetailItem(label: "Salary", value: "$\(String(format: "%.2f", salary))"))
        return items
    }
}

// MARK: - Initialization
//extension CrewMember {
//    init(id: String = UUID().uuidString,
//         name: String,
//         avatar: String,
//         role: String,
//         status: Status = .available,
//         salary: Double = 0.0) {
//        self.id = id
//        self.name = name
//        self.avatar = avatar
//        self.role = role
//        self.status = status
//        self.salary = salary
//    }
//}

// MARK: - Identifiable Conformance
//extension CrewMember: Identifiable { }

