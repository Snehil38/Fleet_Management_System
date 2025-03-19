import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var type: MessageType = .text
}

enum MessageType {
    case text
    case action(actions: [QuickAction])
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

struct ChatBotView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedRole = CommunicationRole.fleetManager
    @State private var message = ""
    @FocusState private var isFocused: Bool
    
    enum CommunicationRole: String, CaseIterable {
        case fleetManager = "Fleet Manager"
        case maintenance = "Maintenance"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Role Selector
                Picker("Select Role", selection: $selectedRole) {
                    ForEach(CommunicationRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Contact Card
                ContactCard(role: selectedRole)
                    .padding(.horizontal)
                
                Spacer()
                
                // Message Input
                MessageInputField(message: $message, isFocused: _isFocused) {
                    sendMessage()
                }
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
    }
    
    private func sendMessage() {
        // Handle sending message
        message = ""
        isFocused = false
    }
}

struct ContactCard: View {
    let role: ChatBotView.CommunicationRole
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: role == .fleetManager ? "person.2.fill" : "wrench.and.screwdriver.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(role == .fleetManager ? "John Smith" : "Mike Johnson")
                        .font(.headline)
                    Text(role.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "phone.fill")
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Text(role == .fleetManager ? "Available: Mon-Fri, 9AM-5PM" : "Available: 24/7")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct MessageInputField: View {
    @Binding var message: String
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $message)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .focused($isFocused)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(message.isEmpty ? .gray : .blue)
            }
            .disabled(message.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray5)),
            alignment: .top
        )
    }
}

#Preview {
    ChatBotView()
} 
