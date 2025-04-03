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
                    print("🔔 Banner tapped")
                    onTap()
                    dismiss()
                }
        )
        .onAppear {
            print("🔔 NotificationBannerView appeared")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
            }
        }
    }
    
    private func dismiss() {
        print("🔔 Dismissing banner")
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

private struct BannerContainer: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @Binding var showingNotifications: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.showBanner, let notification = viewModel.currentBannerNotification {
                VStack {
                    NotificationBannerView(
                        notification: notification,
                        onTap: {
                            print("🔔 Banner tapped, showing notifications")
                            showingNotifications = true
                        },
                        onDismiss: {
                            print("🔔 Banner dismissed")
                            viewModel.dismissBanner()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showBanner)
        .zIndex(999)
    }
}

struct NotificationBannerModifier: ViewModifier {
    @ObservedObject var viewModel: NotificationsViewModel
    @Binding var showingNotifications: Bool
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            BannerContainer(
                viewModel: viewModel,
                showingNotifications: $showingNotifications
            )
        }
    }
}

extension View {
    func notificationBanner(viewModel: NotificationsViewModel, showingNotifications: Binding<Bool>) -> some View {
        modifier(NotificationBannerModifier(viewModel: viewModel, showingNotifications: showingNotifications))
    }
} 