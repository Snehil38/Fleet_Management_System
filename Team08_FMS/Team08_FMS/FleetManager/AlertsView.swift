import SwiftUI

struct AlertRow: View {
    var event: GeofenceEvents

    var body: some View {
        HStack(spacing: 16) {
            // Icon with refined styling
            Image(systemName: event.isRead ? "bell" : "bell.fill")
                .font(.system(size: 24))
                .foregroundColor(event.isRead ? .gray : .blue)
                .padding(6)
                .background(Color(UIColor.systemGray6))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(event.isRead ? .body : .headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("Trip: \(event.tripId.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(event.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            // Use a subtle blue tint for unread alerts instead of yellow.
            RoundedRectangle(cornerRadius: 12)
                .fill(event.isRead ? Color(UIColor.systemBackground) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: event.isRead ? 0.5 : 0)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}

struct AlertsView: View {
    @ObservedObject var supabase = SupabaseDataController.shared
    @State private var events: [GeofenceEvents] = SupabaseDataController.shared.geofenceEvents
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if events.isEmpty {
                    // Native empty state design
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Alerts")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    List {
                        ForEach(events.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                            AlertRow(event: event)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color(UIColor.systemGroupedBackground))
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if !event.isRead {
                                        Button {
                                            markAsRead(event)
                                        } label: {
                                            Label("Mark as Read", systemImage: "checkmark")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteEvent(event)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    // Using PlainListStyle minimizes the extra spacing compared to InsetGroupedListStyle.
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back button to dismiss the view
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    // MARK: - Helper Methods
    
    func markAsRead(_ event: GeofenceEvents) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isRead = true
            // Optionally update the server state here
        }
    }
    
    func deleteEvent(_ event: GeofenceEvents) {
        events.removeAll { $0.id == event.id }
        // Optionally delete from the server/database here
    }
}
