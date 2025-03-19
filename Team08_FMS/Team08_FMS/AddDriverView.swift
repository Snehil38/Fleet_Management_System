//
//  AddDriverView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct AddDriverView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: CrewDataManager
    
    // Driver information
    @State private var driverID = ""
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var licenseType = "Class A CDL"
    @State private var status: CrewMember.Status = .available
    
    // Additional fields
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var address = ""
    @State private var dateOfBirth = Date()
    @State private var licenseExpiration = Date()
    
    // Available license types
    let licenseTypes = ["Class A CDL", "Class B CDL", "Class C CDL", "Non-CDL"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text("Add New Driver")
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
                            TextField("Driver ID (optional)", text: $driverID)
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
                            
                            TextField("Address", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    
                    // Professional Details
                    GroupBox(label:
                                HStack {
                        Image(systemName: "briefcase.fill")
                        Text("Professional Details")
                            .font(.headline)
                    }
                    ) {
                        VStack(spacing: 15) {
                            TextField("Experience (years)", text: $experience)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            VStack(alignment: .leading) {
                                Text("License Type")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("License Type", selection: $licenseType) {
                                    ForEach(licenseTypes, id: \.self) {
                                        Text($0)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            VStack(alignment: .leading) {
                                Text("License Expiration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $licenseExpiration, displayedComponents: .date)
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .labelsHidden()
                                    .frame(maxHeight: 100)
                                    .clipped()
                            }
                            
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
                    
                    // Personal Information
                    GroupBox(label:
                                HStack {
                        Image(systemName: "person.text.rectangle.fill")
                        Text("Personal Information")
                            .font(.headline)
                    }
                    ) {
                        VStack(alignment: .leading) {
                            Text("Date of Birth")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .frame(maxHeight: 100)
                                .clipped()
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: saveDriver) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Driver")
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
    func saveDriver() {
        // Create a new driver with the entered information
        let newDriver = CrewMember(
            id: driverID.isEmpty ? "DR-\(Int.random(in: 1000...9999))" : driverID,
            name: name,
            avatar: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            role: "Driver",
            status: status,
            details: [
                DetailItem(label: "Experience", value: "\(experience) years"),
                DetailItem(label: "License", value: licenseType),
                DetailItem(label: "Phone", value: phoneNumber),
                DetailItem(label: "Email", value: email)
            ]
        )
        
        // Add the new driver to the data manager
        dataManager.addDriver(newDriver)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
    
  
}

#Preview {
    AddDriverView()
        .environmentObject(CrewDataManager())
}
