import SwiftUI

struct MaintenancePersonnelProfileView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var isAvailable: Bool = true
    @State private var showingPasswordReset = false
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingPasswordAlert = false
    @State private var passwordAlertMessage: String = ""
    @State private var showingLogoutAlert = false
    @State private var showingStatusAlert = false
    @State private var lastStatusChangeDate: Date = Date()
    @State private var pendingStatusChange: Bool = false
    
    let user = MaintenancePersonnel(
        name: "John Doe",
        profileImage: "person.circle.fill",
        email: "john.doe@fleetmanagement.com",
        phoneNumber: "+1 234 567 8900",
        yearsOfExperience: 2,
        specialty: "Truck Maintenance",
        avatar: ""
    )
    
    // Computed binding for the availability toggle.
    private var availabilityBinding: Binding<Bool> {
        Binding<Bool>(
            get: { isAvailable },
            set: { newValue in
                if newValue == false {
                    showingStatusAlert = true
                    pendingStatusChange = true
                } else {
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
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    ProfileHeaderView(user: user)
                    
                    AvailabilityView(isAvailable: isAvailable, binding: availabilityBinding)
                    
                    ActionButtonsView(
                        onResetPassword: { showingPasswordReset = true },
                        onLogout: { showingLogoutAlert = true }
                    )
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            // Status Change Alert
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
            // Logout Alert
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    SupabaseDataController.shared.signOut()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            // Password Reset Sheet
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
            // Password Reset Alert
            .alert("Password Reset", isPresented: $showingPasswordAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(passwordAlertMessage)
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: MaintenancePersonnel
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: user.profileImage)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.blue)
                .padding()
            
            Text(user.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(user.phoneNumber)  // Ensure this matches your model
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Displaying specialty as the role; adjust as needed.
            Text(user.specialty)
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
    }
}

struct AvailabilityView: View {
    let isAvailable: Bool
    let binding: Binding<Bool>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Availability Status")
                .font(.headline)
                .padding(.horizontal)
            
            HStack {
                Text(isAvailable ? "Available" : "Unavailable")
                    .foregroundColor(isAvailable ? .green : .red)
                Spacer()
                Toggle("", isOn: binding)
                    .tint(isAvailable ? .green : .red)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct ActionButtonsView: View {
    var onResetPassword: () -> Void
    var onLogout: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: onResetPassword) {
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
            
            Button(action: onLogout) {
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

//struct MaintenancePersonnel {
//    let name: String
//    let email: String
//    let phone: String
//    let role: String
//    let profileImage: String
//}

#Preview {
    MaintenancePersonnelProfileView()
} 
