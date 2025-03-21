import Foundation

enum TripStatus: String, Codable {
    case upcoming = "UPCOMING"
    case current = "CURRENT"
    case delivered = "DELIVERED"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).uppercased()
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