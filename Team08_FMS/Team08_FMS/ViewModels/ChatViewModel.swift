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

struct ChatNotificationPayload: Codable {
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
    @Published var isRefreshing = false
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private let recipientId: UUID
    private let recipientType: RecipientType
    private var realtimeChannel: RealtimeChannel?
    private var refreshTimer: Timer?
    private var hasLoadedMessages = false
    private var lastMessageTimestamp: Date?
    private var currentTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5
    private var lastRefreshTime: Date = .distantPast
    
    private lazy var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = {
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Create date formatters for different formats
            let formatters = [
                // Standard ISO8601
                ISO8601DateFormatter(),
                
                // Custom formatters for different formats
                DateFormatter().apply { formatter in
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                },
                DateFormatter().apply { formatter in
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                },
                DateFormatter().apply { formatter in
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                },
                DateFormatter().apply { formatter in
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                }
            ]
            
            // Try each formatter
            for formatter in formatters {
                if let formatter = formatter as? ISO8601DateFormatter,
                   let date = formatter.date(from: dateString) {
                    return date
                } else if let formatter = formatter as? DateFormatter,
                          let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
    }()
    
    init(recipientId: UUID, recipientType: RecipientType) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        
        setupInitialLoad()
    }
    
    private func setupInitialLoad() {
        // Cancel any existing task
        currentTask?.cancel()
        
        // Create new task for initial setup
        currentTask = Task { @MainActor in
            // Ensure we haven't been cancelled
            guard !Task.isCancelled else { return }
            
            do {
                await loadMessages()
                try await setupMessageListener()
                updateUnreadCount()
                setupRefreshTimer()
            } catch {
                print("Setup error: \(error)")
            }
        }
    }
    
    private func setupMessageListener() async throws {
        // Cleanup existing channel
        realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        
        let channel = supabaseDataController.supabase.realtime
            .channel("chat_messages")
        
        channel.on("postgres_changes", filter: .init(
            event: "*",
            schema: "public",
            table: "chat_messages"
        )) { [weak self] payload in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Ensure enough time has passed since last refresh
                let now = Date()
                guard now.timeIntervalSince(self.lastRefreshTime) >= self.debounceInterval else {
                    return
                }
                
                self.lastRefreshTime = now
                await self.silentRefresh()
            }
        }
        
        channel.subscribe()
        self.realtimeChannel = channel
    }
    
    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                let now = Date()
                guard now.timeIntervalSince(self.lastRefreshTime) >= self.debounceInterval else {
                    return
                }
                
                self.lastRefreshTime = now
                await self.silentRefresh()
            }
        }
    }
    
    private func loadMessages() async {
        // Cancel any existing task
        currentTask?.cancel()
        
        // Don't reload if we already have messages
        guard !hasLoadedMessages else { return }
        
        isLoading = true
        
        // Create new task for loading messages
        currentTask = Task { @MainActor in
            defer { 
                isLoading = false
                currentTask = nil
            }
            
            do {
                guard !Task.isCancelled,
                      let currentUserId = await supabaseDataController.getUserID() else {
                    return
                }
                
                let query = supabaseDataController.supabase
                    .from("chat_messages")
                    .select()
                    .or("and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString)),and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
                    .order("created_at", ascending: true)
                
                let response = try await query.execute()
                
                // Check for cancellation after network request
                guard !Task.isCancelled else { return }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = dateDecodingStrategy
                
                var fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
                let userRole = supabaseDataController.userRole
                
                // Process messages
                for index in fetchedMessages.indices {
                    guard !Task.isCancelled else { return }
                    
                    var message = fetchedMessages[index]
                    message.isFromCurrentUser = userRole == "fleet_manager" ?
                        message.fleet_manager_id.uuidString == currentUserId.uuidString :
                        message.recipient_id.uuidString != currentUserId.uuidString
                    
                    fetchedMessages[index] = message
                    
                    if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                        await markMessageAsRead(message.id)
                    }
                }
                
                self.messages = fetchedMessages
                self.hasLoadedMessages = true
                
                if let lastMessage = fetchedMessages.last {
                    self.lastMessageTimestamp = lastMessage.created_at
                }
                
            } catch {
                guard !Task.isCancelled else { return }
                print("Error loading messages: \(error)")
                self.error = error
            }
        }
    }
    
    private func silentRefresh() async {
        await fetchNewMessages(showLoadingIndicator: false)
    }
    
    func refreshMessages() async {
        await fetchNewMessages(showLoadingIndicator: true)
    }
    
    private func fetchNewMessages(showLoadingIndicator: Bool) async {
        // Cancel any existing task
        currentTask?.cancel()
        
        if showLoadingIndicator {
            isRefreshing = true
        }
        
        // Create new task for fetching messages
        currentTask = Task { @MainActor in
            defer {
                if showLoadingIndicator {
                    isRefreshing = false
                }
                currentTask = nil
            }
            
            do {
                guard !Task.isCancelled,
                      let currentUserId = await supabaseDataController.getUserID() else {
                    return
                }
                
                var query = supabaseDataController.supabase
                    .from("chat_messages")
                    .select()
                
                if let lastTimestamp = lastMessageTimestamp {
                    let formatter = ISO8601DateFormatter()
                    query = query.gt("created_at", value: formatter.string(from: lastTimestamp))
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
                
                // Check for cancellation after network request
                guard !Task.isCancelled else { return }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = dateDecodingStrategy
                
                if let newMessages = try? decoder.decode([ChatMessage].self, from: response.data) {
                    for var message in newMessages {
                        guard !Task.isCancelled else { return }
                        
                        message.isFromCurrentUser = userRole == "fleet_manager" ?
                            message.fleet_manager_id.uuidString == currentUserId.uuidString :
                            message.recipient_id.uuidString != currentUserId.uuidString
                        
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            self.messages.append(message)
                            
                            if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                                await markMessageAsRead(message.id)
                            }
                        }
                    }
                    
                    if let lastMessage = self.messages.last {
                        self.lastMessageTimestamp = lastMessage.created_at
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Error fetching messages: \(error)")
            }
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
        let notification = ChatNotificationPayload(
            message: message,
            type: type,
            created_at: ISO8601DateFormatter().string(from: Date()),
            is_read: false
        )
        
        do {
            let response = try await supabaseDataController.supabase
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
                
                let response = try await supabaseDataController.supabase
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
        currentTask?.cancel()
        refreshTimer?.invalidate()
        realtimeChannel?.unsubscribe()
    }
}

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
} 
