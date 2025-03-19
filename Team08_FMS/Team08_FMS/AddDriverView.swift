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
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var address = ""
    @State private var dateOfBirth = Date()
    @State private var licenseExpiration = Date()
    @State private var salary: String = ""
    
    let licenseTypes = ["Class A CDL", "Class B CDL", "Class C CDL", "Non-CDL"]
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !experience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !salary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(salary) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Driver ID", text: $driverID)
                        .textInputAutocapitalization(.never)
                        .onChange(of: driverID) { oldValue, newValue in
                            if !newValue.isEmpty {
                                driverID = newValue.uppercased()
                            }
                        }
                    TextField("Full Name", text: $name)
                    TextField("Avatar Initials", text: $avatar)
                        .onChange(of: name) {
                            if avatar.isEmpty {
                                let words = name.components(separatedBy: " ")
                                avatar = words.compactMap { $0.first }.map(String.init).joined()
                            }
                        }
                }
                
                // Contact Information
                Section("Contact Information") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Address", text: $address)
                }
                
                // Professional Details
                Section("Professional Details") {
                    TextField("Experience (years)", text: $experience)
                        .keyboardType(.numberPad)
                    
                    Picker("License Type", selection: $licenseType) {
                        ForEach(licenseTypes, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    DatePicker("License Expiration", selection: $licenseExpiration, displayedComponents: .date)
                }
                
                // Personal Information
                Section("Personal Information") {
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                }
                
                // Add Salary Section
                Section("Compensation") {
                    TextField("Monthly Salary", text: $salary)
                        .keyboardType(.decimalPad)
                        .onChange(of: salary) { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                salary = filtered
                            }
                        }
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDriver()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func saveDriver() {
        let newDriver = CrewMember(
            id: driverID.isEmpty ? "DR-\(Int.random(in: 1000...9999))" : driverID,
            name: name,
            avatar: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            role: "Driver",
            status: .available,
            salary: Double(salary) ?? 0
//            details: [
//                DetailItem(label: "Experience", value: "\(experience) years"),
//                DetailItem(label: "License", value: licenseType),
//                DetailItem(label: "Phone", value: phoneNumber),
//                DetailItem(label: "Email", value: email)
//            ]
        )
        dataManager.addDriver(newDriver)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddDriverView()
        .environmentObject(CrewDataManager())
}
