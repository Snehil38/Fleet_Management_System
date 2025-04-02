import SwiftUI
import Combine
@preconcurrency import Supabase

struct Notification: Identifiable, Codable {
    let id: UUID
    let message: String
    let type: String
    let created_at: Date
    var is_read: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, message, type, created_at, is_read
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        message = try container.decode(String.self, forKey: .message)
        type = try container.decode(String.self, forKey: .type)
        is_read = try container.decode(Bool.self, forKey: .is_read)
        
        // Handle multiple date formats
        let dateString = try container.decode(String.self, forKey: .created_at)
        
        // Try different date formats
        if let date = Notification.supabaseDateFormatter.date(from: dateString) {
            created_at = date
        } else if let date = Notification.supabaseMicrosecondsFormatter.date(from: dateString) {
            created_at = date
        } else if let date = Notification.iso8601Formatter.date(from: dateString) {
            created_at = date
        } else if let timestamp = Double(dateString) {
            created_at = Date(timeIntervalSince1970: timestamp)
        } else {
            print("Failed to parse date: \(dateString)")
            throw DecodingError.dataCorruptedError(forKey: .created_at,
                  in: container,
                  debugDescription: "Date string \(dateString) cannot be parsed")
        }
    }
    
    // Supabase PostgreSQL timestamp format without microseconds
    private static let supabaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Supabase PostgreSQL timestamp format with microseconds
    private static let supabaseMicrosecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ" // Format for timestamps with microseconds
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // ISO8601 formatter as fallback
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    private var realtimeChannel: RealtimeChannel?
    private let supabaseDataController = SupabaseDataController.shared
    
    init() {
        Task {
            await setupNotificationListener()
            await loadNotifications()
        }
    }
    
    private func setupNotificationListener() async {
        realtimeChannel?.unsubscribe()
        
        let channel = supabaseDataController.supabase.realtime
            .channel("notifications")
        
        channel.on("postgres_changes", filter: .init(
            event: "*",
            schema: "public",
            table: "notifications"
        )) { [weak self] payload in
            guard let self = self else { return }
            
            Task { @MainActor in
                print("Received notification update: \(payload)")
                await self.loadNotifications()
            }
        }
        
        channel.subscribe()
        print("Subscribed to notifications channel")
        
        await MainActor.run {
            self.realtimeChannel = channel
        }
    }
    
    func loadNotifications() async {
        isLoading = true
        error = nil // Reset error state
        
        do {
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
            
            let decoder = JSONDecoder()
            // We don't need to set dateDecodingStrategy since we handle it in the Notification model
            
            let fetchedNotifications = try decoder.decode([Notification].self, from: response.data)
            
            await MainActor.run {
                self.notifications = fetchedNotifications
                self.unreadCount = fetchedNotifications.filter { !$0.is_read }.count
                self.isLoading = false
            }
        } catch {
            print("Error loading notifications: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func markAsRead(_ notificationId: UUID) async {
        do {
            try await supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notificationId)
                .execute()
            
            await loadNotifications()
        } catch {
            print("Error marking notification as read: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func markAllAsRead() async {
        do {
            try await supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("is_read", value: false)
                .execute()
            
            await loadNotifications()
        } catch {
            print("Error marking all notifications as read: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func deleteNotification(_ notificationId: UUID) async {
        do {
            try await supabaseDataController.supabase.database
                .from("notifications")
                .delete()
                .eq("id", value: notificationId)
                .execute()
            
            await loadNotifications()
        } catch {
            print("Error deleting notification: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    deinit {
        realtimeChannel?.unsubscribe()
    }
} 