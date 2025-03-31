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
        
        // Only set up realtime listener and refresh timer
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
            
            // Build the base query
            var query = supabaseDataController.supabase
                .from("chat_messages")
                .select()
            
            // Filter messages based on the conversation participants
            if userRole == "fleet_manager" {
                // For fleet manager: show messages where they are either sender or recipient
                query = query.or("and(fleet_manager_id.eq.\(currentUserId),recipient_id.eq.\(recipientId)),and(fleet_manager_id.eq.\(recipientId),recipient_id.eq.\(currentUserId))")
            } else {
                // For driver: show messages where they are either sender or recipient
                query = query.or("and(fleet_manager_id.eq.\(recipientId),recipient_id.eq.\(currentUserId)),and(fleet_manager_id.eq.\(currentUserId),recipient_id.eq.\(recipientId))")
            }
            
            // Add trip_id filter if present
            if let tripId = tripId {
                query = query.eq("trip_id", value: tripId.uuidString)
            }
            
            let response = try await query
                .order("created_at", ascending: true)
                .execute()
            
            print("📥 Fetched messages response: \(String(data: response.data, encoding: .utf8) ?? "no data")")
            
            let decoder = JSONDecoder()
            
            // Create date formatters for both formats
            let basicFormatter = DateFormatter()
            basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            basicFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            basicFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            let fractionalFormatter = DateFormatter()
            fractionalFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            fractionalFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            fractionalFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with fractional seconds first
                if let date = fractionalFormatter.date(from: dateString) {
                    return date
                }
                
                // If that fails, try without fractional seconds
                if let date = basicFormatter.date(from: dateString) {
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
                        message.isFromCurrentUser = message.fleet_manager_id == currentUserId
                    } else {
                        message.isFromCurrentUser = message.recipient_id == recipientId
                    }
                    fetchedMessages[index] = message
                    
                    // Mark as read if needed
                    if message.recipient_id == currentUserId && message.status == .sent {
                        Task {
                            await self.markMessageAsRead(message.id)
                        }
                    }
                }
                
                self.messages = fetchedMessages
                self.isLoading = false
                
                print("📱 Loaded \(fetchedMessages.count) messages")
                for message in fetchedMessages {
                    print("Message: \(message.message_text) - isFromCurrentUser: \(message.isFromCurrentUser)")
                }
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
                let userId: UUID
                do {
                    guard let id = try await supabaseDataController.getUserID() else {
                        throw NSError(domain: "ChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
                    }
                    userId = id
                    print("✅ Current user ID retrieved: \(userId)")
                } catch {
                    print("❌ Error getting user ID: \(error)")
                    self.error = error
                    return
                }
                
                // Get the fleet manager's ID
                let fleetManagerId: UUID
                do {
                    let managers = try await supabaseDataController.fetchFleetManagers()
                    guard !managers.isEmpty,
                          let firstManager = managers.first,
                          let managerId = firstManager.userID else {
                        throw NSError(domain: "ChatError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No fleet manager found"])
                    }
                    fleetManagerId = managerId
                    print("✅ Fleet manager ID retrieved: \(fleetManagerId)")
                } catch {
                    print("❌ Error getting fleet manager: \(error)")
                    self.error = error
                    return
                }
                
                // Get the current user's role
                let userRole = await supabaseDataController.userRole
                print("👤 Current user role: \(userRole)")
                
                // Determine message direction based on user role
                let (messageFleetManagerId, messageRecipientId, messageRecipientType): (UUID, UUID, String)
                
                if userRole == "fleet_manager" {
                    messageFleetManagerId = userId
                    messageRecipientId = recipientId
                    messageRecipientType = recipientType.rawValue
                } else {
                    messageFleetManagerId = fleetManagerId
                    messageRecipientId = userId
                    messageRecipientType = "driver"
                }
                
                print("📤 Sending message with:")
                print("Fleet Manager ID: \(messageFleetManagerId)")
                print("Recipient ID: \(messageRecipientId)")
                print("Recipient Type: \(messageRecipientType)")
                print("Trip ID: \(String(describing: tripId))")
                
                // Format dates with fractional seconds for consistency
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                let currentDate = dateFormatter.string(from: Date())
                
                let messageId = UUID()
                
                // Debug trip_id handling
                print("🔍 Trip ID Debug:")
                print("  - Current tripId: \(String(describing: tripId))")
                print("  - tripId?.uuidString: \(String(describing: tripId?.uuidString))")
                
                // Create message payload for Supabase
                let tripIdString = tripId?.uuidString
                print("  - Final tripIdString: \(String(describing: tripIdString))")
                
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
                    trip_id: tripIdString
                )
                
                print("📦 Message payload being sent to Supabase:")
                dump(payload)
                
                // Convert payload to JSON for debugging
                if let jsonData = try? JSONEncoder().encode(payload),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("📝 JSON Payload:")
                    print(jsonString)
                }
                
                // Insert message into database using the payload
                do {
                    let response = try await supabaseDataController.supabase
                        .from("chat_messages")
                        .insert(payload)
                        .execute()
                    
                    // Try to decode and print the response for debugging
                    if let responseString = String(data: response.data, encoding: .utf8) {
                        print("✅ Supabase response data: \(responseString)")
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
                        trip_id: tripId,
                        isFromCurrentUser: true
                    )
                    
                    // Add message to local state
                    self.messages.append(message)
                    
                    // Verify the message was saved by trying to fetch it
                    do {
                        let verifyResponse = try await supabaseDataController.supabase
                            .from("chat_messages")
                            .select()
                            .eq("id", value: messageId.uuidString)
                            .execute()
                        
                        if let verifyString = String(data: verifyResponse.data, encoding: .utf8) {
                            print("✅ Verification fetch response: \(verifyString)")
                        }
                    } catch {
                        print("❌ Error verifying message save: \(error)")
                    }
                    
                    // Trigger a message reload to ensure consistency
                    await self.loadMessages()
                    
                } catch {
                    print("❌ Error inserting message into Supabase: \(error)")
                    print("Error details: \(error.localizedDescription)")
                    if let data = try? JSONSerialization.data(withJSONObject: ["error": error.localizedDescription], options: .prettyPrinted),
                       let errorString = String(data: data, encoding: .utf8) {
                        print("Error JSON: \(errorString)")
                    }
                    self.error = error
                }
                
            } catch {
                print("❌ Unexpected error: \(error)")
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
} 
