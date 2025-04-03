import SwiftUI
import Combine
@preconcurrency import Supabase

private struct MessagePayload: Encodable {
    let id: String
    let fleet_manager_id: String
    let recipient_id: String
    let recipient_type: String
    let message_text: String
    let status: String
    let created_at: String
    let updated_at: String
    let is_deleted: Bool
    let attachment_url: String?
    let attachment_type: String?
}

private struct NotificationPayload: Encodable {
    let message: String
    let type: String
    let created_at: String
    let is_read: Bool
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var unreadCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private let recipientId: UUID
    private let recipientType: RecipientType
    private var realtimeChannel: RealtimeChannel?
    private var refreshTimer: Timer?
    private var hasLoadedMessages = false
    private var lastMessageId: UUID?
    
    init(recipientId: UUID, recipientType: RecipientType) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        
        // Load messages immediately when initialized
        Task {
            await loadMessages()
        }
        
        // Set up realtime listener and refresh timer
        Task { @MainActor in
            await setupMessageListener()
            updateUnreadCount()
            setupRefreshTimer()
        }
    }
    
    func clearMessages() {
        messages = []
    }
    
    private func setupRefreshTimer() {
        // Cancel existing timer if any
        refreshTimer?.invalidate()
        
        // Create a new timer that refreshes every 5 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchNewMessages()
            }
        }
    }
    
    private func setupMessageListener() async {
        // First, cleanup any existing channel
        if let channel = realtimeChannel {
            channel.unsubscribe()
            realtimeChannel = nil
        }
        
        let channel = supabaseDataController.supabase.realtime
            .channel("chat_messages")
        
        // Set up the channel before subscribing
        channel.on("postgres_changes", filter: .init(
            event: "*",
            schema: "public",
            table: "chat_messages"
        )) { [weak self] payload in
            guard let self = self else { return }
            
            Task { @MainActor in
                await self.fetchNewMessages()
            }
        }
        
        // Subscribe to the channel
        channel.subscribe()
        print("Successfully subscribed to realtime updates")
        
        // Store the channel reference
        self.realtimeChannel = channel
    }
    
    func loadMessages() async {
        guard !hasLoadedMessages else { return }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            guard let currentUserId = await supabaseDataController.getUserID() else {
                print("No current user ID found")
                return
            }
            
            let userRole = supabaseDataController.userRole
            
            // Build the query based on user role and recipient type
            var query = supabaseDataController.supabase
                .from("chat_messages")
                .select()
            
            // Add the appropriate filters based on user role
            if userRole == "fleet_manager" {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString)),and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
            } else {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString)),and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString))")
            }
            
            let response = try await query
                .order("created_at", ascending: true)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            var fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
            
            // Update messages on main thread
            await MainActor.run {
                // Update isFromCurrentUser for each message
                for index in fetchedMessages.indices {
                    var message = fetchedMessages[index]
                    if userRole == "fleet_manager" {
                        message.isFromCurrentUser = message.fleet_manager_id.uuidString == currentUserId.uuidString
                    } else {
                        message.isFromCurrentUser = message.recipient_id.uuidString != currentUserId.uuidString
                    }
                    fetchedMessages[index] = message
                    
                    // Mark as read if needed
                    if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                        Task {
                            await self.markMessageAsRead(message.id)
                        }
                    }
                }
                
                self.messages = fetchedMessages
                self.lastMessageId = fetchedMessages.last?.id
                self.isLoading = false
                self.hasLoadedMessages = true
            }
            
        } catch {
            print("Error loading messages: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func fetchNewMessages() async {
        do {
            guard let currentUserId = await supabaseDataController.getUserID() else { return }
            
            var query = supabaseDataController.supabase
                .from("chat_messages")
                .select()
            
            if let lastId = lastMessageId {
                query = query.gt("id", value: lastId)
            }
            
            let userRole = supabaseDataController.userRole
            if userRole == "fleet_manager" {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString)),and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
            } else {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString)),and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString))")
            }
            
            let response = try await query
                .order("created_at", ascending: true)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            if let newMessages = try? decoder.decode([ChatMessage].self, from: response.data) {
                await MainActor.run {
                    for var message in newMessages {
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            if userRole == "fleet_manager" {
                                message.isFromCurrentUser = message.fleet_manager_id.uuidString == currentUserId.uuidString
                            } else {
                                message.isFromCurrentUser = message.recipient_id.uuidString != currentUserId.uuidString
                            }
                            
                            self.messages.append(message)
                            self.lastMessageId = message.id
                            
                            if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                                Task {
                                    await self.markMessageAsRead(message.id)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error fetching new messages: \(error)")
        }
    }
    
    private func updateUnreadCount() {
        Task {
            do {
                let currentUserId = await supabaseDataController.getUserID()
                
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .select("""
                        count
                    """)
                    .eq("recipient_id", value: currentUserId)
                    .eq("status", value: "sent")
                    .execute()
                
                if let countString = try? JSONDecoder().decode([String: Int].self, from: response.data)["count"] {
                    await MainActor.run {
                        self.unreadCount = countString
                    }
                }
            } catch {
                print("Error updating unread count: \(error)")
            }
        }
    }
    
    private func createNotification(message: String, type: String) async throws {
        let notification = NotificationPayload(
            message: message,
            type: type,
            created_at: ISO8601DateFormatter().string(from: Date()),
            is_read: false
        )
        
        do {
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .insert(notification)
                .select()
                .single()
                .execute()
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                if let id = jsonObject["id"] as? String {
                    print("Notification created with ID: \(id)")
                }
                if let messageText = jsonObject["message"] as? String {
                    print("Notification message: \(messageText)")
                }
            }
        } catch {
            print("Failed to create notification: \(error.localizedDescription)")
            throw error
        }
    }
    
    func sendMessage(_ text: String) {
        Task {
            do {
                guard let currentUserId = await supabaseDataController.getUserID() else {
                    print("No user ID found")
                    return
                }
                
                let userRole = supabaseDataController.userRole
                print("Sending message as role: \(userRole ?? "unknown")")
                
                let (messageFleetManagerId, messageRecipientId): (UUID, UUID)
                
                if userRole == "fleet_manager" {
                    messageFleetManagerId = currentUserId
                    messageRecipientId = recipientId
                } else {
                    messageFleetManagerId = recipientId
                    messageRecipientId = currentUserId
                }
                
                let message = ChatMessage(
                    id: UUID(),
                    fleet_manager_id: messageFleetManagerId,
                    recipient_id: messageRecipientId,
                    recipient_type: recipientType.rawValue,
                    message_text: text,
                    status: .sent,
                    created_at: Date(),
                    updated_at: Date(),
                    is_deleted: false,
                    attachment_url: nil,
                    attachment_type: nil,
                    isFromCurrentUser: true
                )
                
                let response = try await supabaseDataController.supabase.database
                    .from("chat_messages")
                    .insert(message)
                    .select()
                    .single()
                    .execute()
                
                if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    if let id = jsonObject["id"] as? String {
                        print("Message sent with ID: \(id)")
                    }
                    if let messageText = jsonObject["message_text"] as? String {
                        print("Message content: \(messageText)")
                    }
                    
                    // Create notification for fleet manager if message is from driver
                    if userRole != "fleet_manager" {
                        let notificationMessage = "New message from \(recipientType.rawValue): \(text)"
                        try await createNotification(
                            message: notificationMessage,
                            type: "chat_message"
                        )
                    }
                    
                    await MainActor.run {
                        self.messages.append(message)
                    }
                    
                    await loadMessages()
                }
                
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    private func verifyRecipientExists() async throws -> Bool {
        let table = recipientType == .maintenance ? "maintenance_personnel" : "driver"
        print("Checking recipient in table: \(table)")
        print("Recipient ID: \(recipientId)")
        
        let response = try await supabaseDataController.supabase
            .from(table)
            .select("""
                userID,
                name,
                email
            """)
            .execute()
        
        // Print raw response for debugging
        if let responseString = String(data: response.data, encoding: .utf8) {
            print("Raw response: \(responseString)")
        }
        
        struct RecipientResponse: Codable {
            let userID: UUID
            let name: String
            let email: String
        }
        
        let decoder = JSONDecoder()
        if let recipients = try? decoder.decode([RecipientResponse].self, from: response.data) {
            print("Found \(recipients.count) recipients")
            for recipient in recipients {
                print("Recipient: \(recipient.name) (\(recipient.userID))")
                if recipient.userID == recipientId {
                    print("Match found!")
                    return true
                }
            }
        }
        
        print("No matching recipient found")
        return false
    }
    
    func markMessageAsRead(_ messageId: UUID) async {
        do {
            let response = try await supabaseDataController.supabase
                .from("chat_messages")
                .update(["status": "read"])
                .eq("id", value: messageId)
                .execute()
            
            print("Message marked as read: \(response)")
            await MainActor.run {
                self.updateUnreadCount()
            }
        } catch {
            print("Error marking message as read: \(error)")
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
        realtimeChannel?.unsubscribe()
    }
} 
