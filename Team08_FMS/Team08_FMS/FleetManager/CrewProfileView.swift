//
//  CrewProfileView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct DetailItem: Identifiable {
    let id = UUID()
    let label: String
    var value: String
}

struct CrewProfileView: View {
    let crewMember: CrewMember
    @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject private var dataManager: CrewDataManager
    @State private var showingDeleteAlert = false
    @State private var showingMessageSheet = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedDetails: [DetailItem] = []
    @State private var editedPhone: String = ""
    @State private var editedEmail: String = ""
    @State private var editedExperience: String = ""
    @State private var editedSalary: String = ""
    @State private var editedLicense: String = ""  // For drivers
    @State private var editedSpecialty: String = "" // For maintenance

    init(crewMember: CrewMember) {
        self.crewMember = crewMember
        _editedName = State(initialValue: crewMember.name)
        _editedDetails = State(initialValue: crewMember.details)
    }

    var body: some View {
        Form {
            // Basic Information Section
            Section("Basic Information") {
                if isEditing {
                    TextField("Name", text: $editedName)
                    LabeledContent("ID", value: crewMember.id)
                    LabeledContent("Role", value: crewMember.role)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(crewMember.status.rawValue)
                            .foregroundColor(crewMember.status.color)
                    }
                } else {
                    LabeledContent("ID", value: crewMember.id)
                    LabeledContent("Name", value: crewMember.name)
                    LabeledContent("Role", value: crewMember.role)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(crewMember.status.rawValue)
                            .foregroundColor(crewMember.status.color)
                    }
                }
            }

            Section("Contact Information") {
                           if isEditing {
                               TextField("Phone", text: $editedPhone)
                                   .keyboardType(.phonePad)
                               TextField("Email", text: $editedEmail)
                                   .keyboardType(.emailAddress)
                           } else {
                               LabeledContent("Phone", value: getDetail(label: "Phone"))
                               LabeledContent("Email", value: getDetail(label: "Email"))
                           }
                       }

            Section("Professional Details") {
                if isEditing {
                    TextField("Experience (years)", text: $editedExperience)
                        .keyboardType(.numberPad)
                    
                    if crewMember.role == "Driver" {
                        TextField("License Type", text: $editedLicense)
                    } else {
                        TextField("Specialty", text: $editedSpecialty)
                    }
                    
                    TextField("Monthly Salary", text: $editedSalary)
                        .keyboardType(.decimalPad)
                } else {
                    LabeledContent("Experience", value: getDetail(label: "Experience"))
                    if crewMember.role == "Driver" {
                        LabeledContent("License", value: getDetail(label: "License"))
                    } else {
                        LabeledContent("Specialty", value: getDetail(label: "Specialty"))
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
                        Text("Delete \(crewMember.role)")
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
        .alert("Delete \(crewMember.role)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCrew()
            }
        } message: {
            Text("Are you sure you want to delete this crew member? This action cannot be undone.")
        }
    }
    
    private func initializeEditingFields() {
        editedName = crewMember.name
        editedPhone = getDetail(label: "Phone")
        editedEmail = getDetail(label: "Email")
        editedExperience = getDetail(label: "Experience").replacingOccurrences(of: " years", with: "")
        editedSalary = String(format: "%.2f", crewMember.salary)
        if crewMember.role == "Driver" {
            editedLicense = getDetail(label: "License")
        } else {
            editedSpecialty = getDetail(label: "Specialty")
        }
    }

    private func getDetail(label: String) -> String {
        crewMember.details.first(where: { $0.label == label })?.value ?? ""
    }
    
    private func saveChanges() {
        // Update the crew member with edited details
        if crewMember.role == "Driver" {
            dataManager.updateDriver(crewMember.id, name: editedName, details: editedDetails)
        } else {
            dataManager.updateMaintenancePersonnel(crewMember.id, name: editedName, details: editedDetails)
        }
        isEditing = false
    }
    
    private func deleteCrew() {
        if crewMember.role == "Driver" {
            dataManager.deleteDriver(crewMember.id)
        } else {
            dataManager.deleteMaintenancePersonnel(crewMember.id)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

// Add this view for task assignment
struct AssignTaskView: View {
    let crewMember: CrewMember
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
        CrewProfileView(crewMember: CrewMember(
            id: "DR-2025",
            name: "John Doe",
            avatar: "JD",
            role: "Driver",
            status: CrewMember.Status.available,
            salary: 5000.0,
            details: [
                DetailItem(label: "Experience", value: "5 years"),
                DetailItem(label: "License", value: "Class A CDL"),
                DetailItem(label: "Last Active", value: "Today, 10:45 AM"),
                DetailItem(label: "Vehicle", value: "None assigned"),
                DetailItem(label: "Salary", value: "$\(String(format: "%.2f", 5000.0))")
            ]
        ))
    }
}
