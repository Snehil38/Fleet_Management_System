//  AddMaintenancePersonnelView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct AddMaintenancePersonnelView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: SupabaseDataController

    // Maintenance personnel information
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var specialty: Specialization = .engineRepair
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var certification: Certification = .aseCertified
    @State private var salary = ""
    @State private var address = ""

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !experience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !salary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
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
                        ForEach(Specialization.allCases, id: \.self) { specialty in
                            Text(specialty.rawValue)
                        }
                    }
                    
                    Picker("Certification", selection: $certification) {
                        ForEach(Certification.allCases, id: \.self) { certification in
                            Text(certification.rawValue)
                        }
                    }
                    
                    TextField("Salary", text: $salary)
                        .keyboardType(.decimalPad)
                    TextField("Address", text: $address)
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
        let newPersonnel = MaintenancePersonnel(
            userID: UUID(),
            name: name,
            profileImage: avatar.isEmpty ? String(name.prefix(2).uppercased()) : avatar,
            email: email,
            phoneNumber: Int(phoneNumber) ?? 0,
            certifications: certification,
            yearsOfExperience: Int(experience) ?? 0,
            specialty: specialty,
            salary: Double(salary) ?? 5000.0,
            address: address.isEmpty ? nil : address,
            createdAt: Date(),
            status: .available
        )
        
        Task {
            do {
                try await dataManager.insertMaintenancePersonnel(personnel: newPersonnel)
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error inserting maintenance personnel: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    AddMaintenancePersonnelView()
        .environmentObject(SupabaseDataController.shared)
}
