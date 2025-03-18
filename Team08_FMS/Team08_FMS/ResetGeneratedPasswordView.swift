//
//  ResetPasswordView.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct ResetGeneratedPasswordView: View {
    let userID: UUID  // User ID passed from login
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var message: String?
    @State private var showAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set a New Password")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Your password was auto-generated. Please set a new password.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            SecureField("New Password", text: $newPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            Button(action: {
                resetPassword()
            }) {
                Text("Update Password")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }
            .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty)
            .opacity(isLoading || newPassword.isEmpty || confirmPassword.isEmpty ? 0.6 : 1.0)
            
            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Update"),
                message: Text(message ?? "An error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Function to update password in Supabase
    func resetPassword() {
        guard newPassword.count >= 6 else {
            message = "Password must be at least 6 characters long."
            showAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            message = "Passwords do not match."
            showAlert = true
            return
        }

        Task {
            isLoading = true
            let success = await SupabaseDataController.shared.updatePassword(newPassword: newPassword)
            await MainActor.run {
                isLoading = false
                message = success ? "Your password has been updated successfully." : "Failed to update password."
                showAlert = true
            }
        }
    }
}

#Preview {
    ResetGeneratedPasswordView(userID: UUID())
}
