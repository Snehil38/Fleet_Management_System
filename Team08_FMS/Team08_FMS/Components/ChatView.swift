import SwiftUI

enum RecipientType {
    case fleetManager
    case maintenance
    case driver
    
    var displayName: String {
        switch self {
        case .fleetManager:
            return "Fleet Manager"
        case .maintenance:
            return "Maintenance"
        case .driver:
            return "Driver"
        }
    }
}

struct ChatView: View {
    let recipientType: RecipientType
    let recipientName: String
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var isShowingEmergencySheet = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.messages) { _ in
                    withAnimation {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            messageInputView
        }
        .sheet(isPresented: $isShowingEmergencySheet) {
            EmergencyAssistanceView()
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
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: -2)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Create and send message
        viewModel.sendMessage(messageText)
        messageText = ""
        isFocused = false
    }
}

// Preview provider
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(recipientType: .driver, recipientName: "John Smith")
    }
} 