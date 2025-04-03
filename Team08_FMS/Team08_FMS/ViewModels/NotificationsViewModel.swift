import Foundation
import SwiftUI
import Combine
@preconcurrency import Supabase

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentBannerNotification: NotificationItem?
    @Published var showBanner = false
    
    private var realtimeChannel: RealtimeChannel?
    private let supabaseDataController = SupabaseDataController.shared
    private var bannerWorkItem: DispatchWorkItem?
    private var loadingTask: Task<Void, Never>?
    private var lastLoadTime: Date = .distantPast
    private let minimumLoadInterval: TimeInterval = 1.0 // Minimum time between loads
    
    init() {
        Task {
            await setupNotificationListener()
            await loadNotifications()
        }
    }
    
    deinit {
        realtimeChannel?.unsubscribe()
        loadingTask?.cancel()
        bannerWorkItem?.cancel()
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
                
                // Only reload if enough time has passed since last load
                let now = Date()
                if now.timeIntervalSince(self.lastLoadTime) >= self.minimumLoadInterval {
                    await self.loadNotifications()
                    
                    if payload.event == "INSERT" {
                        print("🔔 New notification inserted, checking if should show banner...")
                        await self.handleNewNotification(payload)
                    }
                }
            }
        }
        
        print("🔔 Subscribing to notifications channel...")
        channel.subscribe()
        
        await MainActor.run {
            self.realtimeChannel = channel
        }
    }
    
    private func handleNewNotification(_ payload: RealtimeMessage) async {
        do {
            let decoder = JSONDecoder()
            if let data = try? JSONSerialization.data(withJSONObject: payload.payload["data"] ?? [:]),
               let change = try? decoder.decode(DatabaseChange<NotificationItem>.self, from: data),
               let notification = change.record,
               notification.type.shouldShowBanner && !notification.is_read {
                print("🔔 Showing banner for notification: \(notification.message)")
                await showNotificationBanner(notification)
            }
        } catch {
            print("❌ Error handling new notification: \(error)")
        }
    }
    
    private func showNotificationBanner(_ notification: NotificationItem) async {
        await MainActor.run {
            bannerWorkItem?.cancel()
            
            currentBannerNotification = notification
            withAnimation(.spring()) {
                showBanner = true
            }
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismissBanner()
            }
            bannerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
        }
    }
    
    func dismissBanner() {
        Task { @MainActor in
            withAnimation(.spring()) {
                showBanner = false
                currentBannerNotification = nil
            }
        }
    }
    
    func loadNotifications() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            // Check if enough time has passed since last load
            let now = Date()
            guard now.timeIntervalSince(lastLoadTime) >= minimumLoadInterval else {
                return
            }
            
            isLoading = true
            error = nil
            
            do {
                let response = try await supabaseDataController.supabase.database
                    .from("notifications")
                    .select()
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                
                guard !Task.isCancelled else { return }
                
                let decoder = JSONDecoder()
                let fetchedNotifications = try decoder.decode([NotificationItem].self, from: response.data)
                
                self.notifications = fetchedNotifications
                self.unreadCount = fetchedNotifications.filter { !$0.is_read }.count
                self.isLoading = false
                self.error = nil
                self.lastLoadTime = now
                
                // Show banner for most recent unread notification that should show banner
                if let latestBannerNotification = fetchedNotifications.first(where: { !$0.is_read && $0.type.shouldShowBanner }) {
                    await self.showNotificationBanner(latestBannerNotification)
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                print("❌ Error loading notifications: \(error)")
                self.error = error
                self.isLoading = false
                self.notifications = []
                self.unreadCount = 0
            }
        }
        
        // Wait for the loading task to complete
        await loadingTask?.value
    }
    
    func markAsRead(_ notification: NotificationItem) async {
        do {
            try await supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            await loadNotifications()
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }
    
    func deleteNotification(_ notification: NotificationItem) async {
        do {
            try await supabaseDataController.supabase.database
                .from("notifications")
                .delete()
                .eq("id", value: notification.id)
                .execute()
            
            await loadNotifications()
        } catch {
            print("❌ Failed to delete notification: \(error)")
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
            print("❌ Failed to mark all notifications as read: \(error)")
        }
    }
}

// Helper struct for decoding database changes
private struct DatabaseChange<T: Codable>: Codable {
    let schema: String
    let table: String
    let commit_timestamp: String
    let type: String
    let record: T?
} 