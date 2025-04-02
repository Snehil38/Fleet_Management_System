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
        
        do {
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
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
        }
    }
    
    deinit {
        realtimeChannel?.unsubscribe()
    }
} 