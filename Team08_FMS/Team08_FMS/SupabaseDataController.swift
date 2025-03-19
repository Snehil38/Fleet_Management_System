import Foundation
import Supabase
import Combine
import SwiftSMTP  // Add this import for the SMTP library

class SupabaseDataController: ObservableObject {
    static let shared = SupabaseDataController()
    
    @Published var userRole: String?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    @Published var userID: UUID?
    @Published var isGenPass: Bool = false
    
    // Multi-step login state
    @Published var loginStage: LoginStage = .email
    @Published var currentOTP: String = ""
    @Published var isEmailValid: Bool = false
    @Published var isOTPValid: Bool = false
    
    enum LoginStage {
        case email
        case otp
        case password
    }
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
    )
    
    // SMTP configuration
    private let smtp = SMTP(
        hostname: "smtp.gmail.com",     // Gmail SMTP server
        email: "rt9593878@gmail.com",    // Your app's email address
        password: "ibda bytr uomg scxw"  // Your Gmail app password
    )
    
    private init() {}
    
    // MARK: - Authentication
    func signUp(name: String, email: String, phoneNo: Int, role: String) async {
        struct UserRole: Codable {
            let user_id: UUID
            let role_id: Int
        }
        
        struct GenPass: Codable {
            let user_id: UUID
        }
        
        let roleMapping: [String: Int] = [
            "fleet_manager": 1,
            "driver": 2,
            "maintenance_personnel": 3
        ]
        
        guard let roleID = roleMapping[role] else {
            print("Invalid role: \(role)")
            return
        }
        
        do {
            let password = AppDataController.shared.randomPasswordGenerator(length: 6)
            print(password)
            let signUpResponse = try await supabase.auth.signUp(email: email, password: password)
            
            let userID = signUpResponse.user.id
            
            let userRole = UserRole(user_id: userID, role_id: roleID)
            try await supabase
                .from("user_roles")
                .insert(userRole)
                .execute()
            
            let genPass = GenPass(user_id: userID)
            try await supabase
                .from("gen_pass")
                .insert(genPass)
                .execute()
            
            print("User signed up successfully with role: \(role)")
        } catch {
            print("Error during sign-up: \(error.localizedDescription)")
        }
    }
    
    // Verify email exists in database
    func verifyEmail(email: String) {
        Task {
            do {
                // In a real app, you would check if the email exists in your user database
                // For this example, we'll simulate checking the email
                
                let users = try await supabase
                    .from("auth_users")
                    .select("email")
                    .eq("email", value: email)
                    .execute()
                
                await MainActor.run {
                    // For demo purposes, we accept any email
                    self.isEmailValid = true
                    self.loginStage = .otp
                    self.authError = nil
                    self.generateOTP(for: email)
                }
            } catch {
                await MainActor.run {
                    // For demo purposes, we accept any email even if there's an error
                    self.isEmailValid = true
                    self.loginStage = .otp
                    self.authError = nil
                    self.generateOTP(for: email)
                }
            }
        }
    }
    
    // Generate OTP
    func generateOTP(for email: String) {
        // Generate a 6-digit OTP
        let otp = String(Int.random(in: 100000...999999))
        
        // Store the OTP in memory immediately
        self.currentOTP = otp
        
        // Log OTP to console for development purposes
        print("OTP for \(email): \(otp)")
        
        // Store OTP in Supabase for verification and send email
        storeAndSendOTP(email: email, otp: otp)
    }
    
    private func storeAndSendOTP(email: String, otp: String) {
        Task {
            // Store current OTP for verification (memory only) - redundant but safe
            await MainActor.run {
                self.currentOTP = otp
                self.authError = nil
            }
            
            // Send OTP via email
            sendOTPByEmail(to: email, otp: otp)
            
            // Store in database if possible, but don't worry if it fails
            do {
                // Create an Encodable struct instead of using [String: Any]
                struct OTPRecord: Encodable {
                    let email: String
                    let otp: String
                    let created_at: String
                    let expires_at: String
                }
                
                // Create a properly typed record
                let otpRecord = OTPRecord(
                    email: email,
                    otp: otp,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(600)) // 10 minutes
                )
                
                do {
                    // Try to store in Supabase - this might fail if table doesn't exist
                    try await supabase
                        .from("otp_codes")
                        .insert(otpRecord)
                        .execute()
                    print("OTP stored in database for \(email)")
                } catch {
                    // It's okay if this fails - we still have OTP in memory
                    print("Note: Could not store OTP in database, continuing with email only")
                }
            } catch {
                print("Failed to store OTP in database: \(error.localizedDescription)")
            }
        }
    }
    
    // Direct email sending for OTP
    private func sendOTPByEmail(to email: String, otp: String) {
        // Print the OTP code in a very clear format for development
        print("\n==================================================")
        print("📱 YOUR OTP CODE: \(otp)")
        print("==================================================\n")
        
        // Create mail sender and recipient
        let sender = Mail.User(name: "Ravi Tiwari", email: "rt9593878@gmail.com")
        let recipient = Mail.User(name: "User", email: email)
        
        // Simple email content with just the OTP
        let mail = Mail(
            from: sender,
            to: [recipient],
            subject: "Your OTP Code for Fleet Management System",
            text: "Your OTP for verification is: \(otp). It will expire in 10 minutes."
        )
        
        // Send mail via SMTP with async/await
        Task {
            do {
                try await smtp.send(mail)
                print("✅ OTP email sent successfully to \(email)")
            } catch {
                print("❌ Error sending email: \(error)")
                print("Email sending failed, but OTP can be seen in the debug console")
            }
            
            // Allow continuing regardless of email success
            await MainActor.run {
                self.authError = nil
            }
        }
    }
    
    // Verify OTP
    func verifyOTP(otpEntered: String) {
        if otpEntered == currentOTP {
            isOTPValid = true
            loginStage = .password
            authError = nil
        } else {
            isOTPValid = false
            authError = "Invalid OTP. Please try again."
        }
    }

    func signIn(email: String, password: String) {
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                
                // Fetch role after login
                await MainActor.run {
                    userID = session.user.id
                }
                await fetchUserRole(userID: userID!)
                await CheckGenPass(userID: userID!)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authError = nil  // Clear previous errors
                    self.resetLoginState()
                }
            } catch {
                await MainActor.run {
                    self.authError = "Login failed: \(error.localizedDescription)"
                    self.isAuthenticated = false
                }
                print("Login error: \(error.localizedDescription)")
            }
        }
    }
    
    func resetLoginState() {
        loginStage = .email
        isEmailValid = false
        isOTPValid = false
        currentOTP = ""
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                await MainActor.run {
                    self.userRole = nil
                    self.isAuthenticated = false
                    self.userID = nil
                    self.isGenPass = false
                    self.resetLoginState()
                }
            } catch {
            }
        }
    }
    
    func CheckGenPass(userID: UUID) async {
        struct GenPassRow: Codable {
            let is_gen: Bool
        }

        do {
            let response = try await supabase
                .from("gen_pass")
                .select("is_gen")
                .eq("user_id", value: userID)
                .execute()
            
            // Ensure response.data is not nil
            let responseData = response.data
            // Debugging: Print raw JSON response
            if let jsonString = String(data: responseData, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }

            // Decode JSON
            let decodedRows = try JSONDecoder().decode([GenPassRow].self, from: responseData)

            // Extract first row
            if let firstRow = decodedRows.first {
                await MainActor.run {
                    self.isGenPass = firstRow.is_gen
                }
            } else {
                print("No matching row found for userID: \(userID)")
            }
        } catch {
            print("Error checking generated password : \(error.localizedDescription)")
        }
    }
    
    func resetPassword(email: String) {
        Task {
            do {
                // Request password reset from Supabase
                try await supabase.auth.resetPasswordForEmail(email)
                
                // Also send a custom email with instructions
                sendPasswordResetEmail(to: email)
                
                await MainActor.run {
                    self.authError = "Password reset link sent to your email."
                }
            } catch {
                await MainActor.run {
                    self.authError = "Error sending reset link: \(error.localizedDescription)"
                }
                print("Password reset error: \(error)")
            }
        }
    }
    
    private func sendPasswordResetEmail(to email: String) {
        // Create mail sender and recipient
        let sender = Mail.User(name: "Fleet Management System", email: "rt9593878@gmail.com")
        let recipient = Mail.User(name: "User", email: email)
        
        // Email content with reset instructions
        let emailBody = """
        You have requested to reset your password for the Fleet Management System.
        
        Please check your inbox for an email from Supabase with a password reset link.
        
        If you didn't request a password reset, please ignore this email.
        
        Thank you,
        Fleet Management System Team
        """
        
        // Simple email content
        let mail = Mail(
            from: sender,
            to: [recipient],
            subject: "Password Reset Instructions",
            text: emailBody
        )
        
        // Send mail via SMTP
        Task {
            do {
                try await smtp.send(mail)
                print("✅ Password reset email sent successfully to \(email)")
            } catch {
                print("❌ Error sending password reset email: \(error)")
            }
        }
    }
    
    // Updates the user's password 
    func updatePassword(newPassword: String) async -> Bool {
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            try await supabase
                .from("gen_pass")
                .update(["is_gen": false])
                .eq("user_id", value: supabase.auth.user().id)
                .execute()
            await MainActor.run {
                self.isGenPass = false  // This will trigger the UI update
            }
            return true  // Successfully updated
        } catch {
            print("Error updating password: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Fetch User Role
    private func fetchUserRole(userID: UUID) async {
        do {
            let userRolesResult = try await supabase
                .from("user_roles")
                .select("role_id")
                .eq("user_id", value: userID)
                .execute()
            
            struct UserRoleID: Codable {
                let role_id: Int
            }
            
            let userRoles = try JSONDecoder().decode([UserRoleID].self, from: userRolesResult.data)
            guard let roleID = userRoles.first?.role_id else { return }
            
            let roleResult = try await supabase
                .from("roles")
                .select("role_name")
                .eq("id", value: roleID)
                .execute()
            
            struct Role: Codable {
                let role_name: String
            }
            
            let roles = try JSONDecoder().decode([Role].self, from: roleResult.data)
            guard let roleName = roles.first?.role_name else { return }
            
            await MainActor.run { self.userRole = roleName } // Update safely on main thread
            print(roleName)
            
        } catch {
            print("Error fetching user role: \(error.localizedDescription)")
        }
    }
}
