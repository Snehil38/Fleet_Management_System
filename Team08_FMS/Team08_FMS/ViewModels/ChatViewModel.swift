import SwiftUI
import Combine
import Supabase

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    
    init() {
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
            var messageToSend: ChatMessage? = nil
            
            do {
                // Get the current user's ID
                guard let userId = try? await supabaseDataController.getUserID() else {
                    print("No user ID found")
                    return
                }
                
                let message = ChatMessage(
                    id: UUID(),
                    fleet_manager_id: userId,
                    recipient_id: UUID(), // Replace with actual recipient ID
                    recipient_type: "driver", // Replace with actual type
                    message_text: text,
                    status: .sent,
                    created_at: Date(),
                    updated_at: Date(),
                    is_deleted: false,
                    attachment_url: nil,
                    attachment_type: nil,
                    isFromCurrentUser: true
                )
                
                messageToSend = message
                
                // Optimistically add message to UI
                await MainActor.run {
                    self.messages.append(message)
                }
                
                let dateFormatter = ISO8601DateFormatter()
                
                // Create a dictionary with explicit types
                let messageDict: [String: Any] = [
                    "id": message.id.uuidString,
                    "fleet_manager_id": message.fleet_manager_id.uuidString,
                    "recipient_id": message.recipient_id.uuidString,
                    "recipient_type": message.recipient_type,
                    "message_text": message.message_text,
                    "status": message.status.rawValue,
                    "created_at": dateFormatter.string(from: message.created_at),
                    "updated_at": dateFormatter.string(from: message.updated_at),
                    "is_deleted": message.is_deleted,
                    "attachment_url": message.attachment_url as Any,
                    "attachment_type": message.attachment_type as Any
                ]
                
                // Convert dictionary to Data
                let jsonData = try JSONSerialization.data(withJSONObject: messageDict)
                
                // Convert back to a dictionary that Supabase can handle
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    let response = try await supabaseDataController.supabase
                        .from("chat_messages")
                        //.insert(jsonDict)
                        .execute()
                    
                    print("Message sent successfully: \(response)")
                }
            } catch {
                print("Error sending message: \(error)")
                // Remove message from UI if failed
                if let message = messageToSend {
                    await MainActor.run {
                        self.messages.removeAll { $0.id == message.id }
                    }
                }
            }
        }
    }
    
    private func setupMessageListener() {
        Task {
            do {
                let channel = supabaseDataController.supabase.realtime
                    .channel("public:chat_messages")
                
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
