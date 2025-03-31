import SwiftUI

enum RecipientType: String {
    case maintenance = "maintenance"
    case driver = "driver"
    
    var displayName: String {
        switch self {
        case .maintenance:
            return "Maintenance"
        case .driver:
            return "Driver"
        }
    }
}

struct ChatView: View {
    let recipientType: RecipientType
    let recipientId: UUID
    let recipientName: String
    let tripId: UUID?
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isShowingEmergencySheet = false
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var tripController = TripDataController.shared
    
    init(recipientType: RecipientType, recipientId: UUID, recipientName: String, tripId: UUID? = nil) {
        self.recipientType = recipientType
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.tripId = tripId
        self._viewModel = StateObject(wrappedValue: ChatViewModel(
            recipientId: recipientId,
            recipientType: recipientType,
            tripId: tripId
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onAppear {
                    scrollProxy = proxy
                    viewModel.clearMessages() // Clear messages when view appears
                }
                .onChange(of: viewModel.messages) { _ in
                    scrollToBottom()
                }
            }
            .refreshable {
                await viewModel.loadMessages()
            }
            
            // Message input with trip details button for drivers
            messageInputView
        }
        .sheet(isPresented: $isShowingEmergencySheet) {
            EmergencyAssistanceView()
        }
    }
    
    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastMessage = viewModel.messages.last {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private var chatHeader: some View {
        HStack {
            // Back button
            Button(action: {
                // Handle back action
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            
            // Recipient info
            VStack(alignment: .leading, spacing: 2) {
                Text(recipientName)
                    .font(.headline)
                Text(recipientType.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
                if tripId != nil {
                    Text("Trip Chat")
                        .font(.caption2)
                        .foregroundColor(ChatThemeColors.primary)
                }
            }
            
            Spacer()
            
            // Emergency button
            Button(action: {
                isShowingEmergencySheet = true
            }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(ChatThemeColors.emergency)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
    
    private var messageInputView: some View {
        VStack(spacing: 8) {
            // Trip details button (only for drivers)
            if let currentTrip = tripController.currentTrip,
               recipientType == .maintenance {
                Button(action: sendTripDetails) {
                    HStack {
                        Image(systemName: "car.fill")
                        Text("Send Trip Details")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ChatThemeColors.primary)
                    .cornerRadius(20)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                // Message text field
                TextField("Type a message...", text: $messageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isFocused)
                
                // Send button
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(messageText.isEmpty ? Color.gray : ChatThemeColors.primary)
                        )
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: -2)
    }
    
    private func sendTripDetails() {
        guard let trip = tripController.currentTrip else { return }
        
        let tripDetails = """
        🚗 Trip Details:
        Vehicle: \(trip.vehicleDetails.make) \(trip.vehicleDetails.model)
        License Plate: \(trip.vehicleDetails.licensePlate)
        
        📍 From: \(trip.startingPoint)
        🎯 To: \(trip.destination)
        
        📅 Scheduled: \(formatDate(trip.startTime ?? Date()))
        🚚 Status: \(trip.status.rawValue)
        📏 Distance: \(trip.distance)
        
        🔍 Additional Info:
        \(trip.notes ?? "No additional notes")
        """
        
        viewModel.sendMessage(tripDetails)
        scrollToBottom()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Create and send message
        viewModel.sendMessage(messageText)
        messageText = ""
        isFocused = false
        
        // Scroll to bottom after sending
        scrollToBottom()
    }
}

// Preview provider
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(
            recipientType: .driver,
            recipientId: UUID(),
            recipientName: "John Smith",
            tripId: UUID()
        )
    }
} 