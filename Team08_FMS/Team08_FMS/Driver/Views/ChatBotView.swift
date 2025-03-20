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
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isTyping = false
    @State private var selectedDepartment: Department = .fleet
    
    enum Department: String, CaseIterable {
        case fleet = "Fleet Management"
        case maintenance = "Maintenance"
    }
    
    let quickActions = [
        QuickAction(title: "Vehicle Breakdown", icon: "wrench.fill", color: .red),
        QuickAction(title: "Medical Emergency", icon: "cross.fill", color: .red),
        QuickAction(title: "Accident", icon: "exclamationmark.triangle.fill", color: .red),
        QuickAction(title: "Weather Conditions", icon: "cloud.rain.fill", color: .orange),
        QuickAction(title: "Route Assistance", icon: "map.fill", color: .blue)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Header
                VStack(spacing: 12) {
                    Text("Emergency Support")
                        .font(.headline)
                    Text("We're here to help 24/7")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Picker("Department", selection: $selectedDepartment) {
                        ForEach(Department.allCases, id: \.self) { department in
                            Text(department.rawValue).tag(department)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 2)
                
                // Department Info
                HStack(spacing: 12) {
                    Image(systemName: selectedDepartment == .fleet ? "car.2.fill" : "wrench.and.screwdriver.fill")
                        .foregroundColor(selectedDepartment == .fleet ? .blue : .orange)
                    Text("Connected to \(selectedDepartment.rawValue)")
                        .font(.subheadline)
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageView(message: message) { action in
                                    handleQuickAction(action)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { oldCount, newCount in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // Quick Actions
                if messages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How can we help?")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickActions) { action in
                                    Button(action: { handleQuickAction(action) }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: action.icon)
                                                .font(.title2)
                                            Text(action.title)
                                                .font(.caption)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 80)
                                        .padding()
                                        .background(action.color.opacity(0.1))
                                        .foregroundColor(action.color)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Message Input
                HStack(spacing: 12) {
                    TextField("Type your message...", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(newMessage.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(newMessage.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 2)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        let userMessage = Message(content: newMessage, isUser: true, timestamp: Date())
        messages.append(userMessage)
        newMessage = ""
        
        // Simulate bot typing
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isTyping = false
            handleBotResponse(to: userMessage)
        }
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        let message = Message(content: action.title, isUser: true, timestamp: Date())
        messages.append(message)
        
        // Simulate bot typing
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isTyping = false
            handleBotResponse(to: message)
        }
    }
    
    private func handleBotResponse(to message: Message) {
        var response = ""
        var type: MessageType = .text
        let department = selectedDepartment.rawValue
        
        switch message.content {
        case "Vehicle Breakdown":
            response = "I understand you're experiencing a breakdown. I've notified our \(department.lowercased()) team and they're on their way. Your location has been shared with them. Would you like me to contact emergency roadside assistance as well?"
            type = .action(actions: [
                QuickAction(title: "Yes, Call Assistance", icon: "phone.fill", color: .green),
                QuickAction(title: "No, Wait for Team", icon: "clock.fill", color: .orange)
            ])
        case "Medical Emergency":
            response = "I'm contacting emergency services right away and notifying your fleet manager. Please stay calm and don't move if injured. Emergency services are being dispatched to your location."
        case "Accident":
            response = "I'm alerting emergency services and your fleet manager immediately. Please ensure you're in a safe location if possible. Do you need medical assistance?"
            type = .action(actions: [
                QuickAction(title: "Need Medical Help", icon: "cross.fill", color: .red),
                QuickAction(title: "No Injuries", icon: "checkmark.circle.fill", color: .green)
            ])
        case "Weather Conditions":
            response = "I'll help you assess the situation and provide guidance. What specific weather challenges are you facing?"
            type = .action(actions: [
                QuickAction(title: "Heavy Rain", icon: "cloud.rain.fill", color: .blue),
                QuickAction(title: "Snow/Ice", icon: "snow", color: .blue),
                QuickAction(title: "Strong Winds", icon: "wind", color: .orange)
            ])
        case "Route Assistance":
            response = "I'll help you find the safest alternative route. Please confirm your current location and I'll provide updated navigation instructions."
        default:
            response = "I understand you need assistance. I'm connecting you with our \(department.lowercased()) team. What specific support do you need?"
        }
        
        let botMessage = Message(content: response, isUser: false, timestamp: Date(), type: type)
        messages.append(botMessage)
    }
}

struct MessageView: View {
    let message: Message
    let onActionSelected: (QuickAction) -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Message bubble
            HStack {
                if message.isUser { Spacer() }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(20)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if !message.isUser { Spacer() }
            }
            
            // Quick actions if available
            if case .action(let actions) = message.type {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button(action: { onActionSelected(action) }) {
                                HStack {
                                    Image(systemName: action.icon)
                                    Text(action.title)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(action.color.opacity(0.1))
                                .foregroundColor(action.color)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ChatBotView_Previews: PreviewProvider {
    static var previews: some View {
        ChatBotView()
    }
} 