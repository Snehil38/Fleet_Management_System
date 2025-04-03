import SwiftUI

enum NotificationType: String, Codable {
    case maintenanceDue = "maintenance_due"
    case tripUpdate = "trip_update"
    case alert = "alert"
    case info = "info"
    
    var iconName: String {
        switch self {
        case .maintenanceDue:
            return "wrench.fill"
        case .tripUpdate:
            return "car.fill"
        case .alert:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .maintenanceDue:
            return .orange
        case .tripUpdate:
            return .blue
        case .alert:
            return .red
        case .info:
            return .gray
        }
    }
}

struct NotificationItem: Identifiable, Codable, Equatable {
    let id: UUID
    let message: String
    let type: NotificationType
    let created_at: Date
    var is_read: Bool
    
    static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case message
        case type
        case created_at
        case is_read
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        message = try container.decode(String.self, forKey: .message)
        type = try container.decode(NotificationType.self, forKey: .type)
        is_read = try container.decode(Bool.self, forKey: .is_read)
        
        // Handle multiple date formats
        let dateString = try container.decode(String.self, forKey: .created_at)
        
        if let date = Self.postgresDateFormatter.date(from: dateString) {
            created_at = date
        } else if let date = Self.backupDateFormatter.date(from: dateString) {
            created_at = date
        } else if let date = Self.iso8601Formatter.date(from: dateString) {
            created_at = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .created_at,
                in: container,
                debugDescription: "Could not parse date string: \(dateString)"
            )
        }
    }
    
    // Primary Postgres timestamp format
    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Backup formatter
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // ISO8601 formatter
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
} 