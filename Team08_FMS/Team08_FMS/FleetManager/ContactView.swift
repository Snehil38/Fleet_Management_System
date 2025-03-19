//import SwiftUICore
//import SwiftUI
//struct ContactView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var selectedRole = CommunicationRole.fleetManager
//    @State private var messageText = ""
//    @State private var messages: [ChatMessage] = []
//    @FocusState private var isTextFieldFocused: Bool
//
//    enum CommunicationRole: String, CaseIterable {
//        case fleetManager = "Fleet Manager"
//        case maintenance = "Maintenance"
//    }
//
//    struct ChatMessage: Identifiable {
//        let id = UUID()
//        let content: String
//        let isFromMe: Bool
//        let timestamp: Date
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Role Selector
//            Picker("Select Role", selection: $selectedRole) {
//                ForEach(CommunicationRole.allCases, id: \.self) { role in
//                    Text(role.rawValue).tag(role)
//                }
//            }
//            .pickerStyle(.segmented)
//            .padding()
//
//            // Contact Card
//            ContactInfoCard(role: selectedRole)
//                .padding(.horizontal)
//
//            // Messages List
//            ScrollViewReader { proxy in
//                ScrollView {
//                    LazyVStack(spacing: 12) {
//                        ForEach(messages) { message in
//                            MessageBubble(message: message)
//                        }
//                    }
//                    .padding()
//                }
//                .onChange(of: messages.count) { _ in
//                    if let lastMessage = messages.last {
//                        withAnimation {
//                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                        }
//                    }
//                }
//            }
//            .background(Color(.systemGroupedBackground))
//
//            // Message Input
//            VStack(spacing: 0) {
//                Divider()
//                HStack(spacing: 12) {
//                    TextField("Type a message...", text: $messageText)
//                        .padding(12)
//                        .background(Color(.systemGray6))
//                        .cornerRadius(20)
//                        .focused($isTextFieldFocused)
//
//                    Button(action: sendMessage) {
//                        Image(systemName: "arrow.up.circle.fill")
//                            .font(.system(size: 28))
//                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
//                    }
//                    .disabled(messageText.isEmpty)
//                }
//                .padding()
//                .background(Color(.systemBackground))
//            }
//        }
//        .navigationTitle("Messages")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button("Done") {
//                    presentationMode.wrappedValue.dismiss()
//                }
//            }
//        }
//    }
//
//    private func sendMessage() {
//        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
//
//        let newMessage = ChatMessage(content: messageText, isFromMe: true, timestamp: Date())
//        messages.append(newMessage)
//        messageText = ""
//
//        // Simulate reply
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            let reply = ChatMessage(
//                content: "Message received. I'll get back to you shortly.",
//                isFromMe: false,
//                timestamp: Date()
//            )
//            messages.append(reply)
//        }
//    }
//}
//
//struct ContactInfoCard: View {
//    let role: ContactView.CommunicationRole
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack(spacing: 12) {
//                Image(systemName: role == .fleetManager ? "person.2.fill" : "wrench.and.screwdriver.fill")
//                    .font(.title2)
//                    .foregroundColor(.blue)
//                    .frame(width: 40, height: 40)
//                    .background(Color.blue.opacity(0.1))
//                    .clipShape(Circle())
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(role == .fleetManager ? "John Smith" : "Mike Johnson")
//                        .font(.headline)
//                    Text(role.rawValue)
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//
//                Spacer()
//
//                Image(systemName: "phone.fill")
//                    .foregroundColor(.blue)
//                    .padding(8)
//                    .background(Color.blue.opacity(0.1))
//                    .clipShape(Circle())
//            }
//
//            Text(role == .fleetManager ? "Available: Mon-Fri, 9AM-5PM" : "Available: 24/7")
//                .font(.caption)
//                .foregroundColor(.gray)
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.05), radius: 5)
//    }
//}
//
//struct MessageBubble: View {
//    let message: ContactView.ChatMessage
//
//    var body: some View {
//        HStack {
//            if message.isFromMe { Spacer() }
//
//            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
//                Text(message.content)
//                    .padding(12)
//                    .background(message.isFromMe ? Color.blue : Color(.systemGray6))
//                    .foregroundColor(message.isFromMe ? .white : .primary)
//                    .cornerRadius(16)
//
//                Text(message.timestamp.formatted(.dateTime.hour().minute()))
//                    .font(.caption2)
//                    .foregroundColor(.gray)
//            }
//
//            if !message.isFromMe { Spacer() }
//        }
//    }
//} 
