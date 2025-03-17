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
                await fetchUserRoles(userID: session.user.id)
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
    private func fetchUserRoles(userID: UUID) async {
        do {
            let result = try await supabase
                .from("user_roles")
                .select("roles(role_name)")
                .eq("user_id", value: userID)
                .execute()
            
            let userRoles = try JSONDecoder().decode([UserRole].self, from: result.data)
            let roles = userRoles.map { $0.roles.role_name }
            print("User roles: \(roles)")
        } catch {
            print("Error fetching user roles: \(error.localizedDescription)")
        }
    }
}
