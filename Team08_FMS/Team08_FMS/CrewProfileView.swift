import SwiftUI

struct CrewProfileView: View {
    let crewMember: CrewMember
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with profile info
                VStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Text(crewMember.avatar)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    // Name and role
                    VStack(spacing: 4) {
                        Text(crewMember.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("\(crewMember.role) • ID: \(crewMember.id)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Status badge
                    Text(crewMember.status.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(crewMember.status.backgroundColor)
                        .foregroundColor(crewMember.status.color)
                        .cornerRadius(20)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Details section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(crewMember.details) { detail in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detail.label)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(detail.value)
                                    .font(.body)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        // Action for assigning task
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Assign Task")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Action for sending message
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Send Message")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to List")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        })
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
}

#Preview {
    NavigationView {
        CrewProfileView(crewMember: CrewMember(
            id: "DR-2025",
            name: "John Doe",
            avatar: "JD",
            role: "Driver",
            status: .available,
            details: [
                DetailItem(label: "Experience", value: "5 years"),
                DetailItem(label: "License", value: "Class A CDL"),
                DetailItem(label: "Last Active", value: "Today, 10:45 AM"),
                DetailItem(label: "Vehicle", value: "None assigned")
            ]
        ))
    }
} 