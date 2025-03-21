import Foundation

enum TripStatus: String, Codable {
    case upcoming = "upcoming"
    case current = "current"
    case delivered = "delivered"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        if let status = TripStatus(rawValue: rawValue) {
            self = status
        } else {
            self = .upcoming // Default value if unknown
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
} 