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
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private let recipientId: UUID
    private let recipientType: RecipientType
    
    init(recipientId: UUID, recipientType: RecipientType) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        loadMessages()
        setupMessageListener()
    }
    
    func loadMessages() {
        isLoading = true
        
        Task {
            do {
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .select()
                    .or("recipient_id.eq.\(recipientId),fleet_manager_id.eq.\(recipientId)")
                    .order("created_at", ascending: true)
                    .execute()
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                var fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
                
                // Get current user ID to set isFromCurrentUser
                if let currentUserId = try? await supabaseDataController.getUserID() {
                    fetchedMessages = fetchedMessages.map { message in
                        var updatedMessage = message
                        updatedMessage.isFromCurrentUser = message.fleet_manager_id == currentUserId
                        return updatedMessage
                    }
                }
                
                await MainActor.run {
                    self.messages = fetchedMessages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
                print("Error loading messages: \(error)")
            }
        }
    }
    
    func sendMessage(_ text: String) {
        Task {
            do {
                // Get the current user's ID
                guard let userId = try? await supabaseDataController.getUserID() else {
                    print("No user ID found")
                    return
                }
                
                // Create message payload
                let message = ChatMessage(
                    id: UUID(),
                    fleet_manager_id: userId,
                    recipient_id: recipientId,
                    recipient_type: recipientType.rawValue.lowercased(),
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
                
                // Add message to local state
                await MainActor.run {
                    self.messages.append(message)
                }
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
    
    private func setupMessageListener() {
        Task {
            do {
                let channel = supabaseDataController.supabase.realtime
                    .channel("chat_messages")
                
                try await channel.subscribe()
                
                channel.on("postgres_changes", filter: .init(event: "*", schema: "public", table: "chat_messages")) { [weak self] change in
                    guard let self = self else { return }
                    print("New message received: \(change)")
                    Task { @MainActor in
                        await self.loadMessages()
                    }
                }
            } catch {
                print("Error setting up realtime listener: \(error)")
            }
        }
    }
    
    func markMessageAsRead(_ messageId: UUID) {
        Task {
            do {
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .update(["status": "read"])
                    .eq("id", value: messageId)
                    .execute()
                
                print("Message marked as read: \(response)")
            } catch {
                print("Error marking message as read: \(error)")
            }
        }
    }
} 
