import SwiftUI

struct MaintenancePersonnelProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAvailable: Bool = true
    @State private var showingLogoutAlert = false
    @State private var showingPasswordReset = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingPasswordAlert = false
    @State private var passwordAlertMessage = ""
    @State private var showingStatusAlert = false
    @State private var lastStatusChangeDate: Date = Date()
    @State private var pendingStatusChange: Bool = false
    
    // Sample user data - In a real app, this would come from a user service
    let user = MaintenancePersonnel(
        name: "John Doe",
        email: "john.doe@fleetmanagement.com",
        phone: "+1 234 567 8900",
        role: "Senior Maintenance Technician",
        profileImage: "person.circle.fill"
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Image
                    Image(systemName: user.profileImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.blue)
                        .padding()
                    
                    // User Details
                    VStack(spacing: 15) {
                        Text(user.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text(user.phone)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text(user.role)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                    // Availability Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Availability Status")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Text(isAvailable ? "Available" : "Unavailable")
                                .foregroundColor(isAvailable ? .green : .red)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isAvailable },
                                set: { newValue in
                                    if newValue == false {
                                        showingStatusAlert = true
                                        pendingStatusChange = true
                                    } else {
                                        // Check if 24 hours have passed since last status change
                                        let calendar = Calendar.current
                                        let now = Date()
                                        if let nextDay = calendar.date(byAdding: .day, value: 1, to: lastStatusChangeDate),
                                           now >= nextDay {
                                            isAvailable = newValue
                                            lastStatusChangeDate = now
                                        } else {
                                            showingStatusAlert = true
                                            pendingStatusChange = false
                                        }
                                    }
                                }
                            ))
                            .tint(isAvailable ? .green : .red)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    
                    // Password Reset Button
                    Button(action: {
                        showingPasswordReset = true
                    }) {
                        HStack {
                            Image(systemName: "lock.rotation")
                            Text("Reset Password")
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Logout Button
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Status Change", isPresented: $showingStatusAlert) {
                if pendingStatusChange {
                    Button("Continue", role: .none) {
                        isAvailable = false
                        lastStatusChangeDate = Date()
                    }
                    Button("Cancel", role: .cancel) {
                        isAvailable = true
                    }
                } else {
                    Button("OK", role: .cancel) { }
                }
            } message: {
                if pendingStatusChange {
                    Text("Are you sure you want to change your status to unavailable? You won't be able to change it back until tomorrow.")
                } else {
                    Text("Your status will automatically change back to available tomorrow.")
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    SupabaseDataController.shared.signOut { result in
                        switch result {
                        case .success:
                            // Navigate to LoginView
                            DispatchQueue.main.async {
                                if let window = UIApplication.shared.windows.first {
                                    window.rootViewController = UIHostingController(rootView: LoginView())
                                }
                            }
                        case .failure(let error):
                            print("Logout failed: \(error.localizedDescription)")
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetView(
                    isPresented: $showingPasswordReset,
                    currentPassword: $currentPassword,
                    newPassword: $newPassword,
                    confirmPassword: $confirmPassword,
                    showingAlert: $showingPasswordAlert,
                    alertMessage: $passwordAlertMessage
                )
            }
            .alert("Password Reset", isPresented: $showingPasswordAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(passwordAlertMessage)
            }
        }
    }
}

struct PasswordResetView: View {
    @Binding var isPresented: Bool
    @Binding var currentPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                }
                
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetPassword()
                    }
                }
            }
        }
    }
    
    private func resetPassword() {
        // Validate passwords
        if currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty {
            alertMessage = "Please fill in all fields"
            showingAlert = true
            return
        }
        
        if newPassword != confirmPassword {
            alertMessage = "New passwords do not match"
            showingAlert = true
            return
        }
        
        if newPassword.count < 8 {
            alertMessage = "New password must be at least 8 characters long"
            showingAlert = true
            return
        }
        
        // Here you would typically make an API call to reset the password
        // For now, we'll just show a success message
        alertMessage = "Password reset successful"
        showingAlert = true
        isPresented = false
        
        // Clear the fields
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
}

struct MaintenancePersonnel {
    let name: String
    let email: String
    let phone: String
    let role: String
    let profileImage: String
}

#Preview {
    MaintenancePersonnelProfileView()
} 
