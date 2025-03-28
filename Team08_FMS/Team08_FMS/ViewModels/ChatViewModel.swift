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
    private var realtimeChannel: RealtimeChannel?
    
    init(recipientId: UUID, recipientType: RecipientType) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        
        // Load initial data
        Task { @MainActor in
            await loadMessages()
            await setupMessageListener()
            updateUnreadCount()
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
            )) { [weak self] _ in
                guard let self = self else { return }
                
                // Dispatch to main thread
                DispatchQueue.main.async {
                    Task { @MainActor in
                        await self.loadMessages()
                        self.updateUnreadCount()
                    }
                }
            }
            
            // Subscribe to the channel
            try await channel.subscribe()
            
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
            
            let response = try await supabaseDataController.supabase
                .from("chat_messages")
                .select()
                .or("recipient_id.eq.\(recipientId),fleet_manager_id.eq.\(recipientId)")
                .order("created_at", ascending: true)
                .execute()
            
            let decoder = JSONDecoder()
            
            // Create date formatter for the specific format we're receiving
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try to parse the date
                if let date = dateFormatter.date(from: dateString) {
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
                    message.isFromCurrentUser = message.fleet_manager_id == currentUserId
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
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("Error loading messages: \(error)")
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
                guard let userId = try? await supabaseDataController.getUserID() else {
                    print("No user ID found")
                    return
                }
                
                // Get the fleet manager's ID
                guard let fleetManagers = try? await supabaseDataController.fetchFleetManagers(),
                      let firstManager = fleetManagers.first,
                      let fleetManagerId = firstManager.userID else {
                    print("No fleet manager found")
                    return
                }
                
                // Get the current user's role
                let userRole = await supabaseDataController.userRole
                print("Current user role: \(userRole)")
                
                // Determine message direction based on user role
                let (messageFleetManagerId, messageRecipientId, messageRecipientType): (UUID, UUID, String)
                
                if userRole == "fleet_manager" {
                    // Fleet manager sending to driver/maintenance
                    messageFleetManagerId = userId
                    messageRecipientId = recipientId
                    messageRecipientType = recipientType.rawValue
                } else {
                    // Driver/maintenance sending to fleet manager
                    messageFleetManagerId = fleetManagerId
                    messageRecipientId = userId
                    messageRecipientType = "driver"
                }
                
                print("Sending message with:")
                print("Fleet Manager ID: \(messageFleetManagerId)")
                print("Recipient ID: \(messageRecipientId)")
                print("Recipient Type: \(messageRecipientType)")
                
                // Format dates in the same format as we receive them
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                let currentDate = dateFormatter.string(from: Date())
                
                // Create message payload
                let message = ChatMessage(
                    id: UUID(),
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
                    isFromCurrentUser: true
                )
                
                // Insert message into database
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .insert(message)
                    .execute()
                
                print("Message sent successfully: \(response)")
                
                // Add message to local state (already on main thread due to @MainActor)
                self.messages.append(message)
                
                // Trigger a message reload to ensure consistency
                await self.loadMessages()
                
            } catch {
                print("Error sending message: \(error)")
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
        // Cleanup channel on deinit
        if let channel = realtimeChannel {
            Task {
                try? await channel.unsubscribe()
            }
        }
    }
} 
