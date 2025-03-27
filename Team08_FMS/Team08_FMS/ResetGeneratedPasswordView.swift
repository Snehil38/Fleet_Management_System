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
    @State private var isNewPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var message: String?
    @State private var showAlert: Bool = false
    
    // Computed property that returns true if all password criteria are met.
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasUppercase = newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialChar = newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "#$@!%&*?")) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        return hasMinLength && hasUppercase && hasSpecialChar && hasNumber && passwordsMatch
    }
    
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
            
            // New Password Field with view password toggle
            ZStack(alignment: .trailing) {
                Group {
                    if isNewPasswordVisible {
                        TextField("New Password", text: $newPassword)
                            .autocapitalization(.none)
                    } else {
                        SecureField("New Password", text: $newPassword)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                Button(action: {
                    isNewPasswordVisible.toggle()
                }) {
                    Image(systemName: isNewPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 30)
                }
            }
            
            SecureField("Confirm Password", text: $confirmPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            // Always display the password criteria view
            ResetPasswordCriteriaView(newPassword: newPassword, confirmPassword: confirmPassword)
            
            Button(action: {
                resetPassword()
            }) {
                Text("Update Password")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isPasswordValid ? Color.blue : Color.blue.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }
            .disabled(isLoading || !isPasswordValid)
            
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
    
    // Validates the password using regex (this remains for backend consistency).
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[#$@!%&*?])[A-Za-z\\d#$@!%&*?]{6,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }
    
    // Function to update password in Supabase.
    private func resetPassword() {
        // Using the isPasswordValid computed property ensures all criteria are met.
        guard isPasswordValid else {
            message = "Please ensure your password meets all the requirements."
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

struct ResetPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isNewPasswordVisible: Bool = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Computed property to check if the new password meets all criteria.
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasUppercase = newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialChar = newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "#$@!%&*?")) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        return hasMinLength && hasUppercase && hasSpecialChar && hasNumber && passwordsMatch
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Password")) {
                    // New Password Field with view toggle
                    ZStack(alignment: .trailing) {
                        Group {
                            if isNewPasswordVisible {
                                TextField("Enter new password", text: $newPassword)
                                    .autocapitalization(.none)
                            } else {
                                SecureField("Enter new password", text: $newPassword)
                            }
                        }
                        Button(action: {
                            isNewPasswordVisible.toggle()
                        }) {
                            Image(systemName: isNewPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                
                // Display password criteria as a separate section.
                Section {
                    ResetPasswordCriteriaView(newPassword: newPassword, confirmPassword: confirmPassword)
                }
                
                Section {
                    Button("Reset Password") {
                        // Here you would handle the password reset logic.
                        // For demonstration, we'll simply show a success message.
                        alertMessage = "Password successfully reset."
                        showingAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(isPasswordValid ? .blue : .gray)
                    .disabled(!isPasswordValid)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Reset Password"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertMessage == "Password successfully reset." {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
}

struct ResetPasswordCriteriaView: View {
    let newPassword: String
    let confirmPassword: String
    
    // Computed properties for individual criteria
    var isMinLength: Bool { newPassword.count >= 6 }
    var hasUppercase: Bool { newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil }
    var hasSpecialChar: Bool {
        let specialCharacters = CharacterSet(charactersIn: "#$@!%&*?")
        return newPassword.rangeOfCharacter(from: specialCharacters) != nil
    }
    var hasNumber: Bool { newPassword.rangeOfCharacter(from: .decimalDigits) != nil }
    var passwordsMatch: Bool { newPassword == confirmPassword && !newPassword.isEmpty }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Password Requirements")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            criteriaRow(isMet: isMinLength, text: "At least 6 characters")
            criteriaRow(isMet: hasUppercase, text: "Contains an uppercase letter")
            criteriaRow(isMet: hasSpecialChar, text: "Contains a special character")
            criteriaRow(isMet: hasNumber, text: "Contains a number")
            criteriaRow(isMet: passwordsMatch, text: "Passwords match")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func criteriaRow(isMet: Bool, text: String) -> some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isMet ? .green : .red)
                .font(.title3)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    ResetGeneratedPasswordView(userID: UUID())
}
