import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Error Loading Notifications")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            Task {
                                await viewModel.loadNotifications()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.headline)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationCell(notification: notification) {
                                Task {
                                    await viewModel.markAsRead(notification.id)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNotification(notification.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !viewModel.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAsRead()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NotificationCell: View {
    let notification: Notification
    let onTap: () -> Void
    
    private var iconName: String {
        switch notification.type {
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
    
    private var iconColor: Color {
        switch notification.type {
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
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.created_at, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: iconName)
                            .foregroundColor(iconColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .font(.system(.body))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if !notification.is_read {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .background(notification.is_read ? Color.clear : Color.blue.opacity(0.05))
    }
} 