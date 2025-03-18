import Foundation
import Supabase
import Combine

class SupabaseDataController: ObservableObject {
    static let shared = SupabaseDataController()
    
    @Published var userRole: String?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
    )
    
    private init() {}
    
    // MARK: - Authentication
    func signUp(name: String, email: String, role: String) async {
        struct UserRole: Codable {
            let user_id: UUID
            let role_id: Int
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
            
            print("User signed up successfully with role: \(role)")
        } catch {
            print("Error during sign-up: \(error.localizedDescription)")
        }
    }

    func signIn(email: String, password: String) {
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                
                // Fetch role after login
                await fetchUserRole(userID: session.user.id)
                
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authError = nil  // Clear previous errors
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
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                await MainActor.run {
                    self.userRole = nil
                    self.isAuthenticated = false
                }
            } catch {
            }
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
