//
//  CrewProfileView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct CrewProfileView: View {
    let crewMember: CrewMember
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: CrewDataManager
    @State private var showingDeleteAlert = false
    @State private var showingMessageSheet = false

    var body: some View {
        Form {
            // Basic Information Section
            Section("Basic Information") {
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

            // Details Section
            Section("Details") {
                ForEach(crewMember.details) { detail in
                    LabeledContent(detail.label, value: detail.value)
                }
            }

            // Message Button Section
            Section {
                Button {
                    showingMessageSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "message.fill")
                        Text("Send Message")
                        Spacer()
                    }
                    .foregroundColor(.blue)
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
        .sheet(isPresented: $showingMessageSheet) {
            NavigationView {
                ContactView()
            }
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
