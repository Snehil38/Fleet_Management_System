import Foundation
import Supabase
import Combine

class SupabaseDataController: ObservableObject {
    static let shared = SupabaseDataController()
    
    @Published var userRole: String?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    @Published var userID: UUID?
    @Published var otpVerified: Bool = false
    
    @Published var is2faEnabled: Bool = false
    
    @Published var roleMatched: Bool = false
    @Published var isGenPass: Bool = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
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

    func signInWithPassword(email: String, password: String, roleName: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                await fetchUserRole(userID: session.user.id)
                var role = ""
                
                if roleName == "Fleet Manager" {
                    role = "fleet_manager"
                } else if roleName == "Driver" {
                    role = "driver"
                } else if roleName == "Maintenance Personnel" {
                    role = "maintenance_personnel"
                } else {
                    await MainActor.run {
                        alertMessage = "No account found for \(email) as a \(roleName). Please check your credentials or select the correct role."
                    }
                    signOut()
                    return
                }
                
                if role == userRole {
                    await MainActor.run {
                        userID = session.user.id
                        self.roleMatched = true
                    }
                    await CheckGenPass(userID: userID!)
                    if isGenPass {
                        await MainActor.run {
                            self.isAuthenticated = true
                        }
                    }
                    await MainActor.run {
                        self.authError = nil
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "No account found for \(email) as a \(roleName). Please check your credentials or select the correct role."
                        showAlert = true
                    }
                    signOut()
                }
                if !is2faEnabled {
                    await MainActor.run {
                        isAuthenticated = true
                    }
                }
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
                await MainActor.run {
                    authError = "Login failed: \(error.localizedDescription)"
                    alertMessage = authError!
                    showAlert = true
                    isAuthenticated = false
                }
                print("Login error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendOTP(email: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            if !isGenPass {
                do {
                    try await supabase.auth.signInWithOTP(email: email)
                    completion(true, nil)
                } catch {
                    signOut()
                    completion(false, error.localizedDescription)
                }
            }
            else {
                await MainActor.run {
                    self.isAuthenticated = true
                }
            }
        }
    }
    
    func verifyOTP(email: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await supabase.auth.verifyOTP(email: email, token: token, type: .magiclink)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.otpVerified = true
                }
                completion(true, nil)
            } catch {
                signOut()
                completion(false, error.localizedDescription)
            }
        }
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
                    self.otpVerified = false
                    self.roleMatched = false
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
