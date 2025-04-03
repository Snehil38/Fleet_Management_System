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
        print("Attempting to parse date: \(dateString)")
        
        // Try different date formats
        if let date = Notification.postgresDateFormatter.date(from: dateString) {
            print("Successfully parsed with postgres formatter")
            created_at = date
        } else if let date = Notification.backupDateFormatter.date(from: dateString) {
            print("Successfully parsed with backup formatter")
            created_at = date
        } else if let date = Notification.iso8601Formatter.date(from: dateString) {
            print("Successfully parsed with ISO8601 formatter")
            created_at = date
        } else {
            print("Failed to parse date with all formatters")
            throw DecodingError.dataCorruptedError(forKey: .created_at,
                  in: container,
                  debugDescription: "Could not parse date string: \(dateString)")
        }
    }
    
    // Primary Postgres timestamp format (2025-03-31 06:20:09+00)
    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Backup formatter for alternative format (2025-03-31T06:20:09+00:00)
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // ISO8601 formatter as final fallback
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
    @Published var currentBannerNotification: Notification?
    @Published var showBanner = false
    
    private var realtimeChannel: RealtimeChannel?
    private let supabaseDataController = SupabaseDataController.shared
    private var bannerWorkItem: DispatchWorkItem?
    
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
                print("🔔 Received notification update: \(payload)")
                
                // Load notifications first
                await self.loadNotifications()
                
                // Show banner for new notifications
                if payload.event == "INSERT" {
                    print("🔔 New notification inserted, showing banner...")
                    await self.showLatestNotificationBanner()
                }
            }
        }
        
        print("🔔 Subscribing to notifications channel...")
        channel.subscribe()
        
        await MainActor.run {
            self.realtimeChannel = channel
        }
    }
    
    private func showLatestNotificationBanner() async {
        await MainActor.run {
            // Show the new notification banner for the most recent unread notification
            if let latestNotification = notifications.first(where: { !$0.is_read }) {
                print("🔔 Showing banner for notification: \(latestNotification.message)")
                
                // Cancel any pending banner dismissal
                bannerWorkItem?.cancel()
                
                // Show the new notification banner
                currentBannerNotification = latestNotification
                showBanner = true
                
                // Auto dismiss after 5 seconds
                let workItem = DispatchWorkItem {
                    self.dismissBanner()
                }
                bannerWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
            }
        }
    }
    
    func dismissBanner() {
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                showBanner = false
                currentBannerNotification = nil
            }
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
            
            print("Raw response data: \(String(data: response.data, encoding: .utf8) ?? "none")")
            
            let decoder = JSONDecoder()
            
            let fetchedNotifications = try decoder.decode([Notification].self, from: response.data)
            
            await MainActor.run {
                self.notifications = fetchedNotifications
                self.unreadCount = fetchedNotifications.filter { !$0.is_read }.count
                self.isLoading = false
                self.error = nil
            }
        } catch {
            print("Error loading notifications: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.notifications = []
                self.unreadCount = 0
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