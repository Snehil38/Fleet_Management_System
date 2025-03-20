//
//  CrewProfileView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct CrewProfileView: View {
    // The crewMember is any type that conforms to CrewMemberProtocol.
    let crewMember: any CrewMemberProtocol
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var dataManager: CrewDataController
    
    // Editing state variables – note that for numeric fields we work with Strings for TextField binding.
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedPhone: String = ""
    @State private var editedEmail: String = ""
    @State private var editedExperience: String = ""
    @State private var editedSalary: String = ""
    @State private var editedLicense: String = ""     // For Driver
    @State private var editedSpecialty: String = ""    // For Maintenance
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Form {
            // Basic Information Section
            Section("Basic Information") {
                if isEditing {
                    TextField("Name", text: $editedName)
                    LabeledContent("ID", value: crewMember.id.uuidString)
                    LabeledContent("Role", value: role)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(crewMember.status.rawValue)
                            .foregroundColor(crewMember.status.color)
                    }
                } else {
                    LabeledContent("ID", value: crewMember.id.uuidString)
                    LabeledContent("Name", value: crewMember.name)
                    LabeledContent("Role", value: role)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(crewMember.status.rawValue)
                            .foregroundColor(crewMember.status.color)
                    }
                }
            }
            
            // Contact Information Section
            Section("Contact Information") {
                if isEditing {
                    TextField("Phone", text: $editedPhone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $editedEmail)
                        .keyboardType(.emailAddress)
                } else {
                    LabeledContent("Phone", value: "\(crewMember.phoneNumber)")
                    LabeledContent("Email", value: crewMember.email)
                }
            }
            
            // Professional Details Section
            Section("Professional Details") {
                if isEditing {
                    TextField("Experience (years)", text: $editedExperience)
                        .keyboardType(.numberPad)
                    if isDriver {
                        TextField("License Number", text: $editedLicense)
                    } else {
                        TextField("Specialty", text: $editedSpecialty)
                    }
                    TextField("Monthly Salary", text: $editedSalary)
                        .keyboardType(.decimalPad)
                } else {
                    if isDriver, let driver = crewMember as? Driver {
                        LabeledContent("Experience", value: "\(driver.yearsOfExperience) years")
                        LabeledContent("License", value: driver.driverLicenseNumber)
                    } else if let maintenance = crewMember as? MaintenancePersonnel {
                        LabeledContent("Experience", value: "\(maintenance.yearsOfExperience) years")
                        LabeledContent("Specialty", value: maintenance.specialty.rawValue)
                    }
                    LabeledContent("Salary", value: "$\(String(format: "%.2f", crewMember.salary))")
                }
            }
            
            // Delete Section
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete \(role)")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(crewMember.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
        }
        .onAppear {
            initializeEditingFields()
        }
        .alert("Delete \(role)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCrew()
            }
        } message: {
            Text("Are you sure you want to delete this crew member? This action cannot be undone.")
        }
    }
    
    // Helper computed properties
    var isDriver: Bool {
        crewMember is Driver
    }
    
    var role: String {
        isDriver ? "Driver" : "Maintenance"
    }
    
    // Initialize the editing fields with the crew member's current values.
    private func initializeEditingFields() {
        editedName = crewMember.name
        editedPhone = "\(crewMember.phoneNumber)"
        editedEmail = crewMember.email
        if isDriver, let driver = crewMember as? Driver {
            editedExperience = "\(driver.yearsOfExperience)"
            editedLicense = driver.driverLicenseNumber
            editedSalary = String(format: "%.2f", driver.salary)
        } else if let maintenance = crewMember as? MaintenancePersonnel {
            editedExperience = "\(maintenance.yearsOfExperience)"
            editedSpecialty = maintenance.specialty.rawValue
            editedSalary = String(format: "%.2f", maintenance.salary)
        }
    }
    
    // Save changes back to the data controller.
    private func saveChanges() {
        if isDriver, let driver = crewMember as? Driver,
           let index = dataManager.drivers.firstIndex(where: { $0.id == driver.id }) {
            dataManager.drivers[index].name = editedName
            dataManager.drivers[index].profileImage = String(editedName.prefix(2).uppercased())
            dataManager.drivers[index].phoneNumber = Int(editedPhone) ?? dataManager.drivers[index].phoneNumber
            dataManager.drivers[index].email = editedEmail
            dataManager.drivers[index].yearsOfExperience = Int(editedExperience) ?? dataManager.drivers[index].yearsOfExperience
            dataManager.drivers[index].driverLicenseNumber = editedLicense
            dataManager.drivers[index].salary = Double(editedSalary) ?? dataManager.drivers[index].salary
            dataManager.drivers[index].updatedAt = Date()
        } else if let maintenance = crewMember as? MaintenancePersonnel,
                  let index = dataManager.maintenancePersonnel.firstIndex(where: { $0.id == maintenance.id }) {
            dataManager.maintenancePersonnel[index].name = editedName
            dataManager.maintenancePersonnel[index].profileImage = String(editedName.prefix(2).uppercased())
            dataManager.maintenancePersonnel[index].phoneNumber = Int(editedPhone) ?? dataManager.maintenancePersonnel[index].phoneNumber
            dataManager.maintenancePersonnel[index].email = editedEmail
            dataManager.maintenancePersonnel[index].yearsOfExperience = Int(editedExperience) ?? dataManager.maintenancePersonnel[index].yearsOfExperience
            dataManager.maintenancePersonnel[index].specialty = Specialization(rawValue: editedSpecialty) ?? dataManager.maintenancePersonnel[index].specialty
            dataManager.maintenancePersonnel[index].salary = Double(editedSalary) ?? dataManager.maintenancePersonnel[index].salary
            dataManager.maintenancePersonnel[index].updatedAt = Date()
        }
        isEditing = false
    }
    
    // Delete the crew member using the appropriate data controller method.
    private func deleteCrew() {
        if isDriver, let driver = crewMember as? Driver {
            dataManager.deleteDriver(driver.id)
        } else if let maintenance = crewMember as? MaintenancePersonnel {
            dataManager.deleteMaintenancePersonnel(maintenance.id)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct AssignTaskView: View {
    let crewMember: any CrewMemberProtocol
    @Environment(\.presentationMode) var presentationMode
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var dueDate = Date()
    
    var body: some View {
        Form {
            Section(header: Text("Task Details")) {
                TextField("Task Title", text: $taskTitle)
                TextField("Description", text: $taskDescription)
                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .navigationTitle("Assign Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Assign") {
                    // Handle task assignment here
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(taskTitle.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationView {
        // Example preview using a Driver. You can substitute with a MaintenancePersonnel instance as needed.
        CrewProfileView(crewMember: Driver(
            name: "Charlie Davis",
            profileImage: "DR",
            email: "charlie.davis@example.com",
            phoneNumber: 555_111_2222,
            driverLicenseNumber: "DL123456",
            driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
            assignedVehicleID: nil,
            address: "123 Main Street",
            salary: 5000.0,
            yearsOfExperience: 5,
            createdAt: Date(),
            updatedAt: Date(),
            isDeleted: false,
            status: .available
        ))
    }
}
