import SwiftUI

struct ContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedRole = CommunicationRole.fleetManager
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isTextFieldFocused: Bool

    enum CommunicationRole: String, CaseIterable {
        case fleetManager = "Fleet Manager"
        case maintenance = "Maintenance"
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let content: String
        let isFromMe: Bool
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            // Role Selector Card
            VStack(spacing: 8) {
                Text("Select Contact")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                Picker("Select Role", selection: $selectedRole) {
                    ForEach(CommunicationRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            // Contact Card with Status
            ContactInfoCard(role: selectedRole)
                .padding(.horizontal)
                .padding(.bottom)

            // Messages List with Card Style
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageCard(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))

            // Message Input Card
            MessageInputCard(messageText: $messageText, isTextFieldFocused: _isTextFieldFocused, onSend: sendMessage)
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newMessage = ChatMessage(content: messageText, isFromMe: true, timestamp: Date())
        messages.append(newMessage)
        messageText = ""

        // Simulate reply
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let reply = ChatMessage(
                content: "Message received. I'll get back to you shortly.",
                isFromMe: false,
                timestamp: Date()
            )
            messages.append(reply)
        }
    }
}

struct ContactInfoCard: View {
    let role: ContactView.CommunicationRole
    @State private var isOnline = true

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: role == .fleetManager ? "person.2.fill" : "wrench.and.screwdriver.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(role == .fleetManager ? "John Smith" : "Mike Johnson")
                            .font(.headline)
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(role.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(role == .fleetManager ? "Available: Mon-Fri, 9AM-5PM" : "Available: 24/7")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Contact Actions
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct MessageCard: View {
    let message: ContactView.ChatMessage

    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                HStack {
                    if !message.isFromMe {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            )
                    }
                    
                    Text(message.content)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(message.isFromMe ? Color.blue : Color(.systemGray6))
                        )
                        .foregroundColor(message.isFromMe ? .white : .primary)
                }
                
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isFromMe { Spacer() }
        }
        .padding(.horizontal, 4)
    }
}

struct MessageInputCard: View {
    @Binding var messageText: String
    @FocusState var isTextFieldFocused: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {}) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                // Text Input
                TextField("Type a message...", text: $messageText)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .focused($isTextFieldFocused)
                
                // Send Button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
} 
