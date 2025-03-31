import SwiftUI
import Combine
import Supabase

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
    let trip_id: String?
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var unreadCount: Int = 0
    @Published var showNotification = false
    @Published var notificationMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private let recipientId: UUID
    private let recipientType: RecipientType
    private let tripId: UUID?
    private var realtimeChannel: RealtimeChannel?
    private var refreshTimer: Timer?
    
    init(recipientId: UUID, recipientType: RecipientType, tripId: UUID? = nil) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        self.tripId = tripId
        
        // Load messages immediately
        Task { @MainActor in
            await loadMessages()
            await setupMessageListener()
            await updateUnreadCount()
            setupRefreshTimer()
        }
    }
    
    private func showTemporaryNotification(_ message: String) {
        Task { @MainActor in
            notificationMessage = message
            showNotification = true
            // Hide notification after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showNotification = false
        }
    }
    
    func clearMessages() {
        messages = []
    }
    
    private func setupRefreshTimer() {
        // Cancel existing timer if any
        refreshTimer?.invalidate()
        
        // Create a new timer that refreshes every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadMessages()
                self?.updateUnreadCount()
            }
        }
    }
    
    private func setupMessageListener() async {
        // First, cleanup any existing channel
        if let channel = realtimeChannel {
            try? await channel.unsubscribe()
            realtimeChannel = nil
        }
        
        do {
            let channel = supabaseDataController.supabase.realtime
                .channel("chat_messages")
            
            // Set up the channel before subscribing
            channel.on("postgres_changes", filter: .init(
                event: "*",
                schema: "public",
                table: "chat_messages"
            )) { [weak self] payload in
                guard let self = self else { return }
                
                // Dispatch to main thread and refresh messages
                DispatchQueue.main.async {
                    Task { @MainActor in
                        print("Realtime update received: \(payload)")
                        await self.loadMessages()
                        self.updateUnreadCount()
                    }
                }
            }
            
            // Subscribe to the channel
            try await channel.subscribe()
            print("Successfully subscribed to realtime updates")
            
            // Store the channel reference
            await MainActor.run {
                self.realtimeChannel = channel
            }
            
        } catch {
            print("Error setting up realtime listener: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func loadMessages() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let currentUserId = try await supabaseDataController.getUserID()
            let userRole = await supabaseDataController.userRole
            
            // Ensure we have a valid currentUserId
            guard let currentUserIdString = currentUserId?.uuidString else {
                throw NSError(domain: "ChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid current user ID"])
            }
            
            // Build the base query
            var query = supabaseDataController.supabase
                .from("chat_messages")
                .select()
            
            // Add trip_id filter if present
            if let tripId = tripId {
                print("🔍 Loading trip-specific messages for trip: \(tripId.uuidString)")
                // For trip-specific chats, only show messages for this trip
                query = query.eq("trip_id", value: tripId.uuidString)
                
                // For trip chats, we want all messages between these participants
                query = query.or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserIdString)),and(fleet_manager_id.eq.\(currentUserIdString),recipient_id.eq.\(recipientId.uuidString))")
            } else {
                // For non-trip chats, filter messages based on the conversation participants
                query = query.or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserIdString)),and(fleet_manager_id.eq.\(currentUserIdString),recipient_id.eq.\(recipientId.uuidString))")
                // Exclude trip-specific messages from general chat
                query = query.is("trip_id", value: nil)
            }
            
            print("🔍 Loading messages with query filters: trip_id=\(String(describing: tripId)), userRole=\(userRole), currentUser=\(currentUserIdString)")
            
            let response = try await query
                .order("created_at", ascending: true)
                .execute()
            
            print("📥 Fetched messages response: \(String(data: response.data, encoding: .utf8) ?? "no data")")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                    "yyyy-MM-dd'T'HH:mm:ss"
                ].map { format -> DateFormatter in
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    return formatter
                }
                
                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            var fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
            
            // Update messages on main thread
            await MainActor.run {
                // Only update messages if we have new ones and not empty
                if !fetchedMessages.isEmpty {
                    // Update isFromCurrentUser for each message
                    for index in fetchedMessages.indices {
                        var message = fetchedMessages[index]
                        
                        if userRole == "fleet_manager" {
                            // For fleet manager: message is from current user if they are the fleet_manager_id
                            message.isFromCurrentUser = message.fleet_manager_id.uuidString == currentUserIdString
                        } else {
                            // For driver: message is from current user if they are the recipient_id
                            message.isFromCurrentUser = message.recipient_id.uuidString == currentUserIdString
                        }
                        
                        fetchedMessages[index] = message
                        
                        print("📱 Message ownership - ID: \(message.id), Text: \(message.message_text)")
                        print("📱 Message details - Fleet Manager ID: \(message.fleet_manager_id.uuidString)")
                        print("📱 Message details - Recipient ID: \(message.recipient_id.uuidString)")
                        print("📱 Message details - Current User: \(currentUserIdString)")
                        print("📱 Message details - Recipient: \(recipientId.uuidString)")
                        print("📱 Message details - Is From Current User: \(message.isFromCurrentUser)")
                        print("📱 Message details - User Role: \(userRole)")
                        
                        // Mark as read if needed
                        if message.recipient_id.uuidString == currentUserIdString && message.status == .sent {
                            Task {
                                await self.markMessageAsRead(message.id)
                            }
                        }
                    }
                }
                
                // Always update messages to ensure consistency
                self.messages = fetchedMessages
                
                self.isLoading = false
                print("📱 Loaded \(fetchedMessages.count) messages")
                print("📱 Messages after update: \(self.messages.map { "id: \($0.id), text: \($0.message_text), isFromCurrentUser: \($0.isFromCurrentUser)" })")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("❌ Error loading messages: \(error)")
            }
        }
    }
    
    private func updateUnreadCount() {
        Task {
            do {
                let currentUserId = try await supabaseDataController.getUserID()
                
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
    
    func sendMessage(_ text: String) {
        Task { @MainActor in
            do {
                // Get the current user's ID
                guard let userId = try await supabaseDataController.getUserID() else {
                    throw NSError(domain: "ChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid current user ID"])
                }
                let userRole = await supabaseDataController.userRole
                
                // Determine message direction based on user role
                let (messageFleetManagerId, messageRecipientId, messageRecipientType): (UUID, UUID, String)
                
                if userRole == "fleet_manager" {
                    // If sender is fleet manager, they are the fleet_manager_id and recipient is the driver
                    messageFleetManagerId = userId
                    messageRecipientId = recipientId
                    messageRecipientType = recipientType.rawValue
                } else {
                    // If sender is driver, the recipientId (which is fleet manager's ID) becomes fleet_manager_id
                    // and the driver (current user) becomes the recipient
                    messageFleetManagerId = recipientId  // recipientId is the fleet manager's ID
                    messageRecipientId = userId         // current user (driver) is the recipient
                    messageRecipientType = "driver"
                }
                
                // Get driver's current trip ID if applicable
                var messageTripId = tripId?.uuidString
                if userRole == "fleet_manager" {
                    // If fleet manager is sending, use the driver's current trip ID
                    do {
                        let response = try await supabaseDataController.supabase
                            .from("driver")
                            .select("currentTripId")
                            .eq("userID", value: recipientId.uuidString)
                            .single()
                            .execute()
                        
                        struct DriverData: Codable {
                            let currentTripId: String?
                        }
                        
                        if let driverData = try? JSONDecoder().decode(DriverData.self, from: response.data),
                           let currentTripId = driverData.currentTripId {
                            messageTripId = currentTripId
                            print("📱 Found driver's current trip ID: \(currentTripId)")
                        }
                    } catch {
                        print("⚠️ Could not fetch driver's current trip ID: \(error)")
                    }
                } else {
                    // If driver is sending, get their own current trip ID
                    do {
                        let response = try await supabaseDataController.supabase
                            .from("driver")
                            .select("currentTripId")
                            .eq("userID", value: userId.uuidString)
                            .single()
                            .execute()
                        
                        struct DriverData: Codable {
                            let currentTripId: String?
                        }
                        
                        if let driverData = try? JSONDecoder().decode(DriverData.self, from: response.data),
                           let currentTripId = driverData.currentTripId {
                            messageTripId = currentTripId
                            print("📱 Found driver's current trip ID: \(currentTripId)")
                        }
                    } catch {
                        print("⚠️ Could not fetch driver's current trip ID: \(error)")
                    }
                }
                
                let messageId = UUID()
                let currentDate = ISO8601DateFormatter().string(from: Date())
                
                print("📝 Sending message with tripId: \(String(describing: messageTripId))")
                print("📝 Message direction - From: \(userRole) (ID: \(userId))")
                print("📝 Message direction - Fleet Manager ID: \(messageFleetManagerId)")
                print("📝 Message direction - Recipient ID: \(messageRecipientId)")
                print("📝 Message direction - Trip ID: \(String(describing: messageTripId))")
                
                let payload = MessagePayload(
                    id: messageId.uuidString,
                    fleet_manager_id: messageFleetManagerId.uuidString,
                    recipient_id: messageRecipientId.uuidString,
                    recipient_type: messageRecipientType,
                    message_text: text,
                    status: MessageStatus.sent.rawValue,
                    created_at: currentDate,
                    updated_at: currentDate,
                    is_deleted: false,
                    attachment_url: nil,
                    attachment_type: nil,
                    trip_id: messageTripId
                )
                
                // Insert message into database
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .insert(payload)
                    .execute()
                
                print("📤 Message sent with payload: \(payload)")
                
                if response.status == 201 {
                    showTemporaryNotification("Message sent successfully")
                }
                
                // Create message object for local state
                let message = ChatMessage(
                    id: messageId,
                    fleet_manager_id: messageFleetManagerId,
                    recipient_id: messageRecipientId,
                    recipient_type: messageRecipientType,
                    message_text: text,
                    status: .sent,
                    created_at: Date(),
                    updated_at: Date(),
                    is_deleted: false,
                    attachment_url: nil,
                    attachment_type: nil,
                    trip_id: UUID(uuidString: messageTripId ?? ""),
                    isFromCurrentUser: true  // Message is always from current user when sending
                )
                
                // Add message to local state
                self.messages.append(message)
                
                // Reload messages to ensure consistency
                await self.loadMessages()
                
            } catch {
                print("❌ Error sending message: \(error)")
                showTemporaryNotification("Failed to send message")
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
        // Cleanup
        refreshTimer?.invalidate()
        if let channel = realtimeChannel {
            Task {
                try? await channel.unsubscribe()
            }
        }
    }
    
    // Add message equality comparison
    private func areMessagesEqual(_ message1: ChatMessage, _ message2: ChatMessage) -> Bool {
        return message1.id == message2.id &&
               message1.message_text == message2.message_text &&
               message1.status == message2.status
    }
} 
