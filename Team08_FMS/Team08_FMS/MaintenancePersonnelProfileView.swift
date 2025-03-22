import SwiftUI

struct MaintenancePersonnelProfileView: View {
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @State private var personnel: MaintenancePersonnel?
    @State private var showingStatusChangeAlert = false
    @State private var pendingStatus: Status?
    @State private var showAlert = false
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if let personnel = personnel {
                    ScrollView {
                        VStack(spacing: 20) {
                            profileHeader(for: personnel)
                            statusToggle(for: personnel)
                            contactInformation(for: personnel)
                            experienceDetails(for: personnel)
                            logoutButton
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                    }
                } else {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { backButton }
            .alert(isPresented: $showingStatusChangeAlert) {
                if pendingStatus == .available {
                    return Alert(
                        title: Text("Confirm Status Change"),
                        message: Text("Your status will be updated to Available."),
                        dismissButton: .default(Text("OK"), action: {
                            Task {
                                if let userID = await supabaseDataController.getUserID() {
                                    await supabaseDataController.updateMaintenancePersonnelStatus(newStatus: .available, userID: userID, id: nil)
                                    self.personnel?.status = .available
                                }
                            }
                        })
                    )
                } else {
                    return Alert(
                        title: Text("Confirm Status Change"),
                        message: Text("Are you sure you want to set your status to Off Duty?"),
                        primaryButton: .cancel(Text("Cancel")),
                        secondaryButton: .default(Text("Confirm"), action: {
                            Task {
                                if let userID = await supabaseDataController.getUserID() {
                                    await supabaseDataController.updateMaintenancePersonnelStatus(newStatus: .offDuty, userID: userID, id: nil)
                                    self.personnel?.status = .offDuty
                                }
                            }
                        })
                    )
                }
            }
//            .alert(isPresented: $showAlert) {
//                Alert(
//                    title: Text("Alert"),
//                    message: Text("Are you sure you want to log out?"),
//                    primaryButton: .destructive(Text("Yes")) {
//                        Task {
//                            SupabaseDataController.shared.signOut()
//                        }
//                    },
//                    secondaryButton: .cancel()
//                )
//            }
            .task { await loadPersonnelData() }
        }
    }
    
    // MARK: - View Components
    
    private func profileHeader(for personnel: MaintenancePersonnel) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text(personnel.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(personnel.email)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func statusToggle(for personnel: MaintenancePersonnel) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                Text(AppDataController.shared.getStatusString(status: personnel.status))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(personnel.status.color)
                
                Toggle("", isOn: statusToggleBinding(for: personnel))
                    .tint(.green)
                    .disabled(personnel.status == .offDuty)
            }
            .padding(.horizontal)
            
            if personnel.status == .offDuty {
                Text("Your status will automatically change back to Available tomorrow.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
            }
            else if personnel.status == .busy {
                Text("You cannot change status while you have a In-Progress Maintenance.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func contactInformation(for personnel: MaintenancePersonnel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTACT INFORMATION")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Phone", value: "\(personnel.phoneNumber)")
                Divider()
                infoRow(title: "Email", value: personnel.email)
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func experienceDetails(for personnel: MaintenancePersonnel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXPERIENCE & DETAILS")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Experience", value: "\(personnel.yearsOfExperience) Years")
                Divider()
                infoRow(title: "Salary", value: "$\(personnel.salary)")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private var logoutButton: some View {
        Button {
            Task {
                supabaseDataController.signOut()
            }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }
    
    private var backButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Back") {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding()
    }
    
    private func statusToggleBinding(for personnel: MaintenancePersonnel) -> Binding<Bool> {
        Binding<Bool>(
            get: { personnel.status == .available },
            set: { newValue in
                if personnel.status == .offDuty { return }
                let newStatus: Status = newValue ? .available : .offDuty
                if newStatus != personnel.status {
                    updatePendingStatus(newStatus: newStatus)
                }
            }
        )
    }
    
    private func updatePendingStatus(newStatus: Status) {
        pendingStatus = newStatus
        showingStatusChangeAlert = true
    }
    
    // MARK: - Alert Computed Property
    
    private var statusChangeAlert: Alert {
        if pendingStatus == .available {
            return Alert(
                title: Text("Confirm Status Change"),
                message: Text("Your status will be updated to Available."),
                dismissButton: .default(Text("OK"), action: {
                    Task {
                        if let userID = supabaseDataController.userID {
                            await supabaseDataController.updateMaintenancePersonnelStatus(newStatus: .available, userID: userID, id: nil)
                            self.personnel?.status = .available
                        }
                    }
                })
            )
        } else {
            return Alert(
                title: Text("Confirm Status Change"),
                message: Text("Are you sure you want to set your status to Off Duty?"),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .default(Text("Confirm"), action: {
                    Task {
                        if let userID = await supabaseDataController.getUserID() {
                            await supabaseDataController.updateMaintenancePersonnelStatus(newStatus: .offDuty, userID: userID, id: nil)
                            self.personnel?.status = .offDuty
                        }
                    }
                })
            )
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPersonnelData() async {
        if let userID = await supabaseDataController.getUserID() {
            do {
                if let fetchedPersonnel = try await supabaseDataController.fetchMaintenancePersonnelByUserID(userID: userID) {
                    self.personnel = fetchedPersonnel
                }
            } catch {
                print("Error fetching personnel: \(error)")
            }
        }
    }
}
