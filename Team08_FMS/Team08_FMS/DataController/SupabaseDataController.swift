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
                    try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: false)
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
    
    // MARK: - Manage Crew Record
    func fetchDriverByUserID(userID: UUID) async throws -> Driver? {
        do {
            let response = try await supabase
                .from("driver")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Driver: \(rawJSON)")
            }
            
            // Decode JSON as an array of dictionaries and extract the first record
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No driver found for userID: \(userID)")
                return nil
            }
            
            // Fix date format for driverLicenseExpiry if present
            if let expiryDate = jsonArray[0]["driverLicenseExpiry"] as? String {
                jsonArray[0]["driverLicenseExpiry"] = expiryDate + "T00:00:00.000Z" // Ensure full ISO8601 with milliseconds
            }
            
            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])
            
            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode into Driver model
            let driver = try decoder.decode(Driver.self, from: transformedData)
            print("Decoded Driver: \(driver)")
            return driver
        } catch {
            print("Error fetching driver: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchMaintenancePersonnelByUserID(userID: UUID) async throws -> MaintenancePersonnel? {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Maintenance Personnel: \(rawJSON)")
            }
            
            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode JSON as an array of dictionaries and extract the first record
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No maintenance personnel found for userID: \(userID)")
                return nil
            }
            
            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])
            
            // Decode into MaintenancePersonnel model
            let personnel = try decoder.decode(MaintenancePersonnel.self, from: transformedData)
            print("Decoded Maintenance Personnel: \(personnel)")
            return personnel
        } catch {
            print("Error fetching maintenance personnel: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchDrivers() async throws -> [Driver] {
        do {
            let response = try await supabase
                .from("driver")
                .select()
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(rawJSON)")
            }

            // Decode JSON as an array of dictionaries first
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }

            // Fix date format for driverLicenseExpiry
            for i in 0..<jsonArray.count {
                if let expiryDate = jsonArray[i]["driverLicenseExpiry"] as? String {
                    jsonArray[i]["driverLicenseExpiry"] = expiryDate + "T00:00:00.000Z" // Ensure full ISO8601 with milliseconds
                }
            }

            // Convert transformed array back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX" // Allows fractional seconds
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into Driver model
            let drivers = try decoder.decode([Driver].self, from: transformedData)
            print("Decoded Drivers: \(drivers)")
            return drivers
        } catch {
            print("Error fetching drivers: \(error)")
            return []
        }
    }
    
    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel] {
        do {
            let response = try await supabase
                .from("maintenance_personnel") // Corrected table name
                .select()
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(rawJSON)")
            }

            // Custom Date Formatter
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX" // Fractional seconds support
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            

            // Decode data
            let personnels = try decoder.decode([MaintenancePersonnel].self, from: data)
            print("Decoded Maintenance Personnel: \(personnels)")
            return personnels
        } catch {
            print("Error fetching maintenance personnel: \(error)")
            return []
        }
    }

    func insertDriver(driver: Driver) async throws {
        let response = try await supabase
            .from("driver")
            .insert(driver)
            .execute()
        // Optionally, you can process the response here
        print("Insert response: \(response)")
    }
    
    func insertMaintenancePersonnel(personnel: MaintenancePersonnel) async throws {
        let response = try await supabase
            .from("maintenance_personnel")
            .insert(personnel)
            .execute()
        // Optionally, you can process the response here
        print("Insert response: \(response)")
    }
}
