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
                
                // First try to get fleet manager details
                let fleetManagerResponse = try await supabaseDataController.supabase
                    .from("fleet_manager")
                    .select()
                    .eq("userID", value: userId)
                    .execute()
                
                // Try to decode as fleet manager first
                let decoder = JSONDecoder()
                var senderType = "fleet_manager"
                var senderId: UUID? = nil
                
                struct FleetManager: Decodable {
                    let id: UUID
                    let userID: UUID
                    
                    enum CodingKeys: String, CodingKey {
                        case id
                        case userID = "userID"
                    }
                }
                
                if let fleetManagers = try? decoder.decode([FleetManager].self, from: fleetManagerResponse.data),
                   let fleetManager = fleetManagers.first {
                    senderId = fleetManager.userID  // Use userID instead of id
                } else {
                    // If not a fleet manager, try to get driver details
                    let driverResponse = try await supabaseDataController.supabase
                        .from("driver")
                        .select("*, fleet_Manager")
                        .eq("userID", value: userId)
                        .execute()
                    
                    struct Driver: Decodable {
                        let id: UUID
                        let userID: UUID
                        let fleet_Manager: UUID
                        
                        enum CodingKeys: String, CodingKey {
                            case id
                            case userID = "userID"
                            case fleet_Manager = "fleet_Manager"
                        }
                    }
                    
                    if let drivers = try? decoder.decode([Driver].self, from: driverResponse.data),
                       let driver = drivers.first {
                        senderType = "driver"
                        senderId = driver.id
                        // For drivers, we need to set the recipient as their fleet manager
                        let fleetManagerId = driver.fleet_Manager
                        
                        let message = ChatMessage(
                            id: UUID(),
                            fleet_manager_id: fleetManagerId, // The fleet manager's ID
                            recipient_id: driver.userID, // Use userID instead of id for the recipient
                            recipient_type: "driver", // Lowercase to match database constraint
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
                        
                        // Create an encodable payload
                        let payload = MessagePayload(
                            id: message.id.uuidString,
                            fleet_manager_id: message.fleet_manager_id.uuidString,
                            recipient_id: message.recipient_id.uuidString,
                            recipient_type: message.recipient_type,
                            message_text: message.message_text,
                            status: message.status.rawValue,
                            created_at: dateFormatter.string(from: message.created_at),
                            updated_at: dateFormatter.string(from: message.updated_at),
                            is_deleted: message.is_deleted,
                            attachment_url: message.attachment_url,
                            attachment_type: message.attachment_type
                        )
                        
                        let insertResponse = try await supabaseDataController.supabase
                            .from("chat_messages")
                            .insert(payload)
                            .execute()
                        
                        print("Message sent successfully: \(insertResponse)")
                        return
                    }
                }
                
                // If we get here and don't have a sender ID, throw an error
                guard let senderId = senderId else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found in either fleet_manager or driver tables"])
                }
                
                // This part only executes for fleet managers
                let message = ChatMessage(
                    id: UUID(),
                    fleet_manager_id: senderId,
                    recipient_id: UUID(), // TODO: Replace with actual driver's userID
                    recipient_type: "driver",
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
                
                // Create an encodable payload
                let payload = MessagePayload(
                    id: message.id.uuidString,
                    fleet_manager_id: message.fleet_manager_id.uuidString,
                    recipient_id: message.recipient_id.uuidString,
                    recipient_type: message.recipient_type,
                    message_text: message.message_text,
                    status: message.status.rawValue,
                    created_at: dateFormatter.string(from: message.created_at),
                    updated_at: dateFormatter.string(from: message.updated_at),
                    is_deleted: message.is_deleted,
                    attachment_url: message.attachment_url,
                    attachment_type: message.attachment_type
                )
                
                let insertResponse = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .insert(payload)
                    .execute()
                
                print("Message sent successfully: \(insertResponse)")
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
