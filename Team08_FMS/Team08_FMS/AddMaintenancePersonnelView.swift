import SwiftUI

struct AddMaintenancePersonnelView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: CrewDataManager
    
    // Maintenance personnel information
    @State private var personnelID = ""
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var specialty = "Engine Repair"
    @State private var status: CrewMember.Status = .available
    
    // Additional fields
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var certification = ""
    
    // Available specialties
    let specialties = ["Engine Repair", "Electrical Systems", "Brake Systems", "Transmission", "HVAC", "General Maintenance"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text("Add Maintenance Personnel")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Form content in a ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Information
                    GroupBox(label:
                        HStack {
                            Image(systemName: "person.fill")
                            Text("Basic Information")
                                .font(.headline)
                        }
                    ) {
                        VStack(spacing: 15) {
                            TextField("Personnel ID (optional)", text: $personnelID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Full Name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Avatar Initials", text: $avatar)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: name) { newValue in
                                    if avatar.isEmpty {
                                        // Auto-generate initials from name
                                        let words = newValue.components(separatedBy: " ")
                                        avatar = words.compactMap { $0.first }.map(String.init).joined()
                                    }
                                }
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    
                    // Contact Information
                    GroupBox(label:
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Contact Information")
                                .font(.headline)
                        }
                    ) {
                        VStack(spacing: 15) {
                            TextField("Phone Number", text: $phoneNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    
                    // Professional Details
                    GroupBox(label:
                        HStack {
                            Image(systemName: "wrench.fill")
                            Text("Professional Information")
                                .font(.headline)
                        }
                    ) {
                        VStack(spacing: 15) {
                            TextField("Experience (years)", text: $experience)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            VStack(alignment: .leading) {
                                Text("Specialty")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Specialty", selection: $specialty) {
                                    ForEach(specialties, id: \.self) {
                                        Text($0)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            TextField("Certification", text: $certification)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            VStack(alignment: .leading) {
                                Text("Status")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Status", selection: $status) {
                                    Text("Available").tag(CrewMember.Status.available)
                                    Text("Busy").tag(CrewMember.Status.busy)
                                    Text("Offline").tag(CrewMember.Status.offline)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: saveMaintenancePersonnel) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Personnel")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(name.isEmpty)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.vertical)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    func saveMaintenancePersonnel() {
        // Create a new maintenance personnel with the entered information
        let newPersonnel = CrewMember(
            id: personnelID.isEmpty ? "MT-\(Int.random(in: 1000...9999))" : personnelID,
            name: name,
            avatar: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            role: "Maintenance",
            status: status,
            details: [
                DetailItem(label: "Specialty", value: specialty),
                DetailItem(label: "Experience", value: "\(experience) years"),
                DetailItem(label: "Certification", value: certification),
                DetailItem(label: "Phone", value: phoneNumber),
                DetailItem(label: "Email", value: email)
            ]
        )
        
        // Add the new maintenance personnel to the data manager
        dataManager.addMaintenancePersonnel(newPersonnel)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddMaintenancePersonnelView()
        .environmentObject(CrewDataManager())
}
