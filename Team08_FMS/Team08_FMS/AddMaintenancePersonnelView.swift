//
//  AddMaintenacePersonnelView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

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
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var certification = ""

    // Available specialties
    let specialties = ["Engine Repair", "Electrical Systems", "Brake Systems", "Transmission", "HVAC", "General Maintenance"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !experience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Personnel ID", text: $personnelID)
                        .textInputAutocapitalization(.never)
                        .onChange(of: personnelID) { oldValue, newValue in
                            if !newValue.isEmpty {
                                personnelID = newValue.uppercased()
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
                }
                
                // Professional Details
                Section("Professional Details") {
                    TextField("Experience (years)", text: $experience)
                        .keyboardType(.numberPad)
                    
                    Picker("Specialty", selection: $specialty) {
                        ForEach(specialties, id: \.self) {
                            Text($0)
                        }
                    }
                    
                    TextField("Certification", text: $certification)
                }
            }
            .navigationTitle("Add Maintenance Personnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMaintenancePersonnel()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveMaintenancePersonnel() {
        let newPersonnel = CrewMember(
            id: personnelID.isEmpty ? "MT-\(Int.random(in: 1000...9999))" : personnelID,
            name: name,
            avatar: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            role: "Maintenance",
            status: .available,
            details: [
                DetailItem(label: "Specialty", value: specialty),
                DetailItem(label: "Experience", value: "\(experience) years"),
                DetailItem(label: "Certification", value: certification),
                DetailItem(label: "Phone", value: phoneNumber),
                DetailItem(label: "Email", value: email)
            ]
        )
        dataManager.addMaintenancePersonnel(newPersonnel)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddMaintenancePersonnelView()
        .environmentObject(CrewDataManager())
}
