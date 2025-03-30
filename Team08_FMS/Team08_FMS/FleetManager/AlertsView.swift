import SwiftUI

struct AlertsView: View {
    @ObservedObject var supabase = SupabaseDataController.shared
    @State private var events: [GeofenceEvents] = []
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                if events.isEmpty {
                    EmptysStateView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary Cards Section
                            SummarySection()
                                .padding(.top, 8)
                                .padding(.horizontal)
                            
                            // Alerts List
                            AlertsListView()
                                .padding(.top, 16)
                        }
                    }
                    .refreshable {
                        loadData()
                    }
                }
            }
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Back Button for modal views
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Helper Methods
    
    func loadData() {
        events = supabase.geofenceEvents.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    func markAsRead(_ event: GeofenceEvents) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index].isRead = true
        }
    }
    
    func deleteEvent(_ event: GeofenceEvents) {
        events.removeAll { $0.id == event.id }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func SummarySection() -> some View {
        HStack(spacing: 12) {
            // Unread Card
            SummaryCard(
                icon: "bell.fill",
                title: "Unread",
                count: events.filter { !$0.isRead }.count,
                color: .blue
            )
            
            // Total Card
            SummaryCard(
                icon: "bell",
                title: "Total",
                count: events.count,
                color: .gray
            )
        }
    }
    
    @ViewBuilder
    private func AlertsListView() -> some View {
        LazyVStack(spacing: 12) {
            ForEach(events) { event in
                AlertRow(event: event)
                    .padding(.horizontal)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !event.isRead {
                            Button {
                                withAnimation {
                                    markAsRead(event)
                                }
                            } label: {
                                Label("Mark as Read", systemImage: "checkmark")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                deleteEvent(event)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptysStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bell.slash.circle.fill")
                    .font(.system(size: 50))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
            }
            
            VStack(spacing: 8) {
                Text("No Alerts")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("You're all caught up!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text("\(count)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct AlertRow: View {
    var event: GeofenceEvents

    var body: some View {
        HStack(spacing: 16) {
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
            RoundedRectangle(cornerRadius: 12)
                .fill(event.isRead ? Color(UIColor.systemBackground) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: event.isRead ? 0.5 : 0)
        )
    }
}
