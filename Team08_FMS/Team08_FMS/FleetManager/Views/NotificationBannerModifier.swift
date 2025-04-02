import SwiftUI

struct NotificationBannerView: View {
    let notification: Notification
    let onTap: () -> Void
    let onDismiss: () -> Void
    @State private var offset: CGFloat = -120
    @State private var shouldShow = true
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForType(notification.type))
                .font(.system(size: 20))
                .foregroundColor(colorForType(notification.type))
                .padding(8)
                .background(colorForType(notification.type).opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(timeAgo(notification.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 16)
            
            // Dismiss button
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .offset(y: offset)
        .gesture(
            TapGesture()
                .onEnded { _ in
                    onTap()
                    dismiss()
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
            }
            
            // Auto dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if shouldShow {
                    dismiss()
                }
            }
        }
    }
    
    private func dismiss() {
        shouldShow = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            offset = -120
        }
        
        // Call onDismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "chat_message":
            return "message.fill"
        case "emergency":
            return "exclamationmark.triangle.fill"
        case "maintenance":
            return "wrench.fill"
        default:
            return "bell.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "chat_message":
            return .blue
        case "emergency":
            return .red
        case "maintenance":
            return .orange
        default:
            return .gray
        }
    }
}

struct NotificationBannerModifier: ViewModifier {
    @ObservedObject var viewModel: NotificationsViewModel
    @Binding var showingNotifications: Bool
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if viewModel.showBanner, let notification = viewModel.currentBannerNotification {
                NotificationBannerView(
                    notification: notification,
                    onTap: {
                        showingNotifications = true
                    },
                    onDismiss: {
                        viewModel.dismissBanner()
                    }
                )
                .padding([.horizontal], 16)
                .padding([.top], getSafeAreaInsets().top)
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let window = UIApplication.shared.windows.first else { return .zero }
        return window.safeAreaInsets
    }
}

extension View {
    func notificationBanner(viewModel: NotificationsViewModel, showingNotifications: Binding<Bool>) -> some View {
        modifier(NotificationBannerModifier(viewModel: viewModel, showingNotifications: showingNotifications))
    }
} 