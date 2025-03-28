import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var isAnimating = false
    
    private var backgroundColor: Color {
        message.isFromCurrentUser ? ChatThemeColors.primary : ChatThemeColors.secondary
    }
    
    private var textColor: Color {
        message.isFromCurrentUser ? .white : ChatThemeColors.text
    }
    
    private var alignment: Alignment {
        message.isFromCurrentUser ? .trailing : .leading
    }
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                Text(message.message_text)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        // Message Status Indicator
                        Group {
                            if message.isFromCurrentUser {
                                HStack {
                                    switch message.status {
                                    case .sent:
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    case .delivered:
                                        Image(systemName: "checkmark.circle")
                                            .font(.caption2)
                                    case .read:
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.trailing, 4)
                                .offset(x: -4, y: 14)
                            }
                        }
                    )
                
                // Timestamp
                Text(formatDate(message.created_at))
                    .font(.caption2)
                    .foregroundColor(ChatThemeColors.timestamp)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .onAppear {
            withAnimation(ChatBubbleAnimation.messageAppearance) {
                isAnimating = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Preview provider
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "Hello, this is a test message that's quite long to see how it wraps",
                status: .delivered,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: true
            ))
            
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "This is a response",
                status: .read,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: false
            ))
        }
        .padding()
    }
} 