import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var isAnimating = false
    @StateObject private var supabaseController = SupabaseDataController.shared
    @State private var currentUserId: UUID?
    
    private var backgroundColor: Color {
        message.isFromCurrentUser ? .blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        message.isFromCurrentUser ? .white : .black
    }
    
    var body: some View {
        HStack {
            // If the message is from current user, place spacer on the left to push content right
            if message.isFromCurrentUser {
                Spacer(minLength: 30)
                messageContent(alignment: .trailing)
            } else {
                // Otherwise, place the content on the left and spacer on the right
                messageContent(alignment: .leading)
                Spacer(minLength: 30)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .onAppear {
            withAnimation(ChatBubbleAnimation.messageAppearance) {
                isAnimating = true
            }
            // Get current user ID when view appears
            Task {
                currentUserId = await supabaseController.getUserID()
            }
        }
    }
    
    private func messageContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(message.message_text)
                .foregroundColor(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            HStack(spacing: 4) {
                Text(formatDate(message.created_at))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if message.isFromCurrentUser {
                    Group {
                        switch message.status {
                        case .sent:
                            Image(systemName: "checkmark")
                        case .delivered:
                            Image(systemName: "checkmark.circle")
                        case .read:
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
            .padding(alignment == .trailing ? .trailing : .leading, 4)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Preview provider for testing layout
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
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
        .previewLayout(.sizeThatFits)
    }
}
