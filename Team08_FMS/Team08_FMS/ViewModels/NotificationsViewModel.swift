import Foundation
import SwiftUI
import Combine
import UserNotifications
@preconcurrency import Supabase

@MainActor
final class NotificationsViewModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentBannerNotification: NotificationItem?
    @Published var showNotificationPermissionAlert = false
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private var realtimeChannel: RealtimeChannel?
    private var bannerWorkItem: DispatchWorkItem?
    private var loadingTask: Task<Void, Never>?
    private let minimumLoadInterval: TimeInterval = 1.0
    private var lastLoadTime: Date = .distantPast
    
    override init() {
        super.init()
        setupNotificationCategories()
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        Task {
            await checkAndRequestNotificationPermission()
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
                
                if payload.event == "INSERT" {
                    print("🔔 New notification received...")
                    if let data = try? JSONSerialization.data(withJSONObject: payload.payload["data"] ?? [:]),
                       let change = try? JSONDecoder().decode(DatabaseChange<NotificationItem>.self, from: data),
                       let notification = change.record {
                        print("🔔 Showing notification: \(notification.message)")
                        await self.showNotification(notification)
                        await self.loadNotifications() // Refresh the list
                    }
                } else {
                    // For other events (update, delete), just refresh the list
                    await self.loadNotifications()
                }
            }
        }
        
        print("🔔 Subscribing to notifications channel...")
        channel.subscribe()
        self.realtimeChannel = channel
    }
    
    private func checkAndRequestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        print("🔔 Current notification settings:")
        print("  - Authorization Status: \(settings.authorizationStatus.rawValue)")
        print("  - Alert Setting: \(settings.alertSetting.rawValue)")
        print("  - Sound Setting: \(settings.soundSetting.rawValue)")
        print("  - Badge Setting: \(settings.badgeSetting.rawValue)")
        
        switch settings.authorizationStatus {
        case .notDetermined:
            print("🔔 Requesting notification permission for the first time...")
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                print("🔔 Notification permission granted: \(granted)")
                if !granted {
                    print("❌ User denied notification permission")
                    await MainActor.run {
                        showNotificationPermissionAlert = true
                    }
                }
            } catch {
                print("❌ Failed to request notification permission: \(error)")
                await MainActor.run {
                    showNotificationPermissionAlert = true
                }
            }
            
        case .denied:
            print("🔔 Notifications are denied, showing settings guidance...")
            await MainActor.run {
                showNotificationPermissionAlert = true
            }
            
        case .authorized, .provisional, .ephemeral:
            print("✅ Notifications are authorized")
            
        @unknown default:
            print("⚠️ Unknown notification authorization status")
        }
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            return
        }
        UIApplication.shared.open(settingsUrl)
    }
    
    private func showNotification(_ notification: NotificationItem) async {
        print("🔔 Starting to process notification: \(notification.id)")
        
        // Skip trip duration and estimated arrival notifications
        if notification.message.contains("Trip duration exceeded") ||
           notification.message.contains("Estimated arrival time reached") {
            print("⏭️ Skipping filtered notification type")
            return
        }
        
        print("🔔 Preparing to show notification: \(notification.message)")
        
        // First check if notifications are authorized
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus == .authorized else {
            print("❌ Cannot show notification - not authorized (current status: \(settings.authorizationStatus.rawValue))")
            await MainActor.run {
                showNotificationPermissionAlert = true
            }
            return
        }
        
        let content = UNMutableNotificationContent()
        
        // Format the title and body based on the message content
        if notification.message.contains("Trip Details:") {
            content.title = "New Trip Assignment"
            print("📝 Formatting trip details notification")
            
            // Extract and format the trip details
            let details = notification.message
                .replacingOccurrences(of: "New message from driver: ", with: "")
                .replacingOccurrences(of: "🚗 ", with: "")
                .replacingOccurrences(of: "📍 ", with: "")
                .replacingOccurrences(of: "🎯 ", with: "")
                .replacingOccurrences(of: "📅 ", with: "")
                .replacingOccurrences(of: "🚚 ", with: "")
                .replacingOccurrences(of: "📏 ", with: "")
                .replacingOccurrences(of: "🔍 ", with: "")
            
            // Create a more concise body
            let lines = details.components(separatedBy: "\n").filter { !$0.isEmpty }
            var body = ""
            
            for line in lines {
                if line.contains("Vehicle:") || 
                   line.contains("From:") || 
                   line.contains("To:") ||
                   line.contains("Status:") {
                    body += line + "\n"
                }
            }
            
            content.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📝 Formatted notification body: \(content.body)")
        } else {
            // For regular messages
            content.title = "New Message"
            content.body = notification.message.replacingOccurrences(of: "New message from driver: ", with: "")
            print("📝 Regular notification body: \(content.body)")
        }
        
        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)
        
        // Add custom data
        content.userInfo = [
            "notification_id": notification.id.uuidString,
            "type": notification.type.rawValue
        ]
        
        content.threadIdentifier = notification.type.rawValue
        content.categoryIdentifier = "NOTIFICATION_CATEGORY"
        
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            print("📋 Checking existing notifications...")
            let pendingRequests = await center.pendingNotificationRequests()
            let deliveredNotifications = await center.deliveredNotifications()
            
            print("  - Pending notifications: \(pendingRequests.count)")
            print("  - Delivered notifications: \(deliveredNotifications.count)")
            
            if pendingRequests.contains(where: { $0.identifier == notification.id.uuidString }) {
                print("⚠️ Notification already scheduled, skipping...")
                return
            }
            
            print("🔔 Scheduling notification...")
            try await center.add(request)
            print("✅ Notification scheduled successfully")
            
            // Show banner in-app as well
            await showNotificationBanner(notification)
            
        } catch {
            print("❌ Error showing notification: \(error)")
            print("  - Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("  - Error domain: \(nsError.domain)")
                print("  - Error code: \(nsError.code)")
                print("  - Error user info: \(nsError.userInfo)")
            }
        }
    }
    
    // Add notification categories and actions
    private func setupNotificationCategories() {
        let markAsReadAction = UNNotificationAction(
            identifier: "MARK_AS_READ",
            title: "Mark as Read",
            options: .authenticationRequired
        )
        
        let category = UNNotificationCategory(
            identifier: "NOTIFICATION_CATEGORY",
            actions: [markAsReadAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func loadNotifications() async {
        guard !Task.isCancelled else { return }
        
        // Check if enough time has passed since last load
        let now = Date()
        guard now.timeIntervalSince(lastLoadTime) >= minimumLoadInterval else {
            print("⏱️ Skipping notification load - too soon since last load")
            return
        }
        
        print("📥 Starting notification load")
        self.isLoading = true
        self.error = nil
        
        do {
            print("🔍 Fetching notifications from database...")
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
            
            guard !Task.isCancelled else { return }
            
            print("🔄 Processing response data...")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Print raw response data for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Raw response data: \(jsonString)")
            }
            
            let fetchedNotifications = try decoder.decode([NotificationItem].self, from: response.data)
            
            print("📋 Loaded \(fetchedNotifications.count) notifications")
            
            // Filter out unwanted notifications in memory
            let filteredNotifications = fetchedNotifications.filter { notification in
                !notification.message.contains("Trip duration exceeded") &&
                !notification.message.contains("Estimated arrival time reached")
            }
            
            print("🎯 Filtered to \(filteredNotifications.count) relevant notifications")
            
            await MainActor.run {
                self.notifications = filteredNotifications
                self.unreadCount = filteredNotifications.filter { !$0.is_read }.count
                print("📬 Unread count: \(self.unreadCount)")
            }
            
            // Update app badge
            try await UNUserNotificationCenter.current().setBadgeCount(self.unreadCount)
            
            // Show unread notifications
            for notification in filteredNotifications where !notification.is_read {
                print("🔔 Processing unread notification: \(notification.id)")
                await self.showNotification(notification)
            }
            
            self.isLoading = false
            self.error = nil
            self.lastLoadTime = now
            
        } catch {
            guard !Task.isCancelled else { return }
            
            print("❌ Error loading notifications: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Log detailed error information
            if let nsError = error as? NSError {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
            }
            
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
            try await self.supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            await self.loadNotifications()
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }
    
    func deleteNotification(_ notification: NotificationItem) async {
        do {
            try await self.supabaseDataController.supabase.database
                .from("notifications")
                .delete()
                .eq("id", value: notification.id)
                .execute()
            
            await self.loadNotifications()
        } catch {
            print("❌ Failed to delete notification: \(error)")
        }
    }
    
    func markAllAsRead() async {
        do {
            try await self.supabaseDataController.supabase.database
                .from("notifications")
                .update(["is_read": true])
                .eq("is_read", value: false)
                .execute()
            
            await self.loadNotifications()
        } catch {
            print("❌ Failed to mark all notifications as read: \(error)")
        }
    }
    
    private func showNotificationBanner(_ notification: NotificationItem) async {
        await MainActor.run {
            bannerWorkItem?.cancel()
            currentBannerNotification = notification
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismissBanner()
            }
            bannerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
        }
    }
    
    func dismissBanner() {
        Task { @MainActor in
            currentBannerNotification = nil
        }
    }
    
    // Add notification delegate methods
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("🔔 Will present notification: \(notification.request.identifier)")
        return [.banner, .sound, .badge]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse) async {
        print("🔔 Did receive notification response: \(response.notification.request.identifier)")
        if let notificationId = response.notification.request.content.userInfo["notification_id"] as? String {
            if let notification = notifications.first(where: { $0.id.uuidString == notificationId }) {
                await markAsRead(notification)
            }
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
