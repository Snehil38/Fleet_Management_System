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
                await self.loadNotifications()
                
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
            if let latestNotification = notifications.first(where: { !$0.is_read }) {
                print("🔔 Showing banner for notification: \(latestNotification.message)")
                
                bannerWorkItem?.cancel()
                
                currentBannerNotification = latestNotification
                withAnimation(.spring()) {
                    showBanner = true
                }
                
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
            withAnimation(.spring()) {
                showBanner = false
                currentBannerNotification = nil
            }
        }
    }
    
    func loadNotifications() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
            
            let decoder = JSONDecoder()
            let fetchedNotifications = try decoder.decode([NotificationItem].self, from: response.data)
            
            await MainActor.run {
                self.notifications = fetchedNotifications
                self.unreadCount = fetchedNotifications.filter { !$0.is_read }.count
                self.isLoading = false
                self.error = nil
            }
        } catch {
            print("❌ Error loading notifications: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.notifications = []
                self.unreadCount = 0
            }
        }
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
            // Update all unread notifications to read
            try await supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("is_read", value: false)
                .execute()
            
            // Reload notifications to update the UI
            await loadNotifications()
        } catch {
            print("❌ Failed to mark all notifications as read: \(error)")
        }
    }
} 