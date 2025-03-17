//
//  SupabaseDataController.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import Foundation
import Supabase

struct UserRole: Codable {
    let roles: Role
}

struct Role: Codable {
    let role_name: String
}

class SupabaseDataController {
    static let shared = SupabaseDataController()
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
    )
    
    private var userRole: String?
    
    private init() {}
    
    // MARK: - Authentication
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                await fetchUserRole(userID: session.user.id)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase.auth.signOut()
                self.userRole = nil
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch User Role
    private func fetchUserRole(userID: UUID) async {
        do {
            // Step 1: Get role_id from user_roles
            let userRolesResult = try await supabase
                .from("user_roles")
                .select("role_id")
                .eq("user_id", value: userID)
                .execute()
            
            // Decode role_id
            struct UserRoleID: Codable {
                let role_id: Int
            }
            
            let userRoles = try JSONDecoder().decode([UserRoleID].self, from: userRolesResult.data)
            
            guard let roleID = userRoles.first?.role_id else {
                print("⚠️ No role assigned to this user.")
                return
            }
            
            print("🔍 Retrieved role_id: \(roleID)")
            
            // Step 2: Get role_name from roles using role_id
            let roleResult = try await supabase
                .from("roles")
                .select("role_name")
                .eq("id", value: roleID)
                .execute()
            
            // Decode role_name
            struct Role: Codable {
                let role_name: String
            }
            
            let roles = try JSONDecoder().decode([Role].self, from: roleResult.data)
            
            guard let roleName = roles.first?.role_name else {
                print("⚠️ Role ID \(roleID) not found in roles table.")
                return
            }
            
            print("✅ User role: \(roleName)")
            
        } catch {
            print("❌ Error fetching user role: \(error.localizedDescription)")
        }
    }

}
