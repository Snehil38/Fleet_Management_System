import Foundation
import Supabase
import Combine
import SwiftSMTP

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
    @Published var session: Session?
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
    )
    
    private init() {
//        Task {
//            await checkSession()
//        }
    }
    
    func sendEmail(toName: String, toEmail: String, subject: String, text: String) {
        let smtp = SMTP(
            hostname: "smtp.gmail.com",     // SMTP server address
            email: "c0sm042532@gmail.com",        // username to login
            password: "xjsk jrno odyh exoe"            // password to login
        )
        let fromUser = Mail.User(name: "Dr. Light", email: "c0sm042532@gmail.com")
        let toUser = Mail.User(name: toName, email: toEmail)
        let mail = Mail(from: fromUser, to: [toUser], subject: subject, text: text)
        smtp.send(mail) { (error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    func setUserSession() async {
        do {
            guard let session = session else {
                print("Cannot set session")
                return
            }
            let accessToken = session.accessToken
            let refreshToken = session.refreshToken
            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print(session)
        } catch {
            print("Cannot set session")
        }
    }
    
    func setSessionManually(userSession: Session) async {
        do {
            let accessToken = userSession.accessToken
            let refreshToken = userSession.refreshToken
            
            // Save tokens
            UserDefaults.standard.set(accessToken, forKey: "accessToken")
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            UserDefaults.standard.synchronize()  // Ensure they are saved

            // Verify the values were saved
            print("Saved accessToken: \(UserDefaults.standard.string(forKey: "accessToken") ?? "nil")")
            print("Saved refreshToken: \(UserDefaults.standard.string(forKey: "refreshToken") ?? "nil")")

            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print("Session set manually: \(userSession)")
        } catch {
            print("Cannot set session: \(error)")
        }
    }
    
    func saveUserDefaults() {
        guard let session = session else {
            print("cannot store user defaults")
            return
        }
        let accessToken = session.accessToken
        let refreshToken = session.refreshToken
        // Save tokens
        UserDefaults.standard.set(accessToken, forKey: "accessToken")
        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        UserDefaults.standard.synchronize()  // Ensure they are saved

        // Verify the values were saved
        print("Saved accessToken: \(UserDefaults.standard.string(forKey: "accessToken") ?? "nil")")
        print("Saved refreshToken: \(UserDefaults.standard.string(forKey: "refreshToken") ?? "nil")")
    }
    
    func autoLogin() async {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
              let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
            print("No saved session found in UserDefaults")
            return
        }

        print("Retrieved accessToken: \(accessToken)")
        print("Retrieved refreshToken: \(refreshToken)")

        do {
            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)

            // Ensure session is valid
            await MainActor.run {
                session = supabase.auth.currentSession
                userID = session?.user.id
            }
            // Fetch user role using the retrieved user ID
            await fetchUserRole(userID: session!.user.id)
            await MainActor.run {
                self.isAuthenticated = true
            }
            print("Auto-login successful")
        } catch {
            print("Auto-login failed: \(error)")
        }
    }

    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            
            await MainActor.run {
                self.isAuthenticated = true
                self.userID = session.user.id
            }
            
            // Fetch additional user-related data
            await fetchUserRole(userID: session.user.id)
            await CheckGenPass(userID: session.user.id)
            
        } catch {
            // If an error occurs, reset the session-related properties
            print("Error checking session: \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthenticated = false
                self.userRole = nil
                self.userID = nil
                self.isGenPass = false
                self.otpVerified = false
            }
        }
    }
    
    // MARK: - Authentication
    func signUp(name: String, email: String, phoneNo: Int, role: String) async -> UUID? {
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
            return nil
        }
        
        do {
            session = supabase.auth.currentSession
            let password = AppDataController.shared.randomPasswordGenerator(length: 6)
            print(password)
            let signUpResponse = try await supabase.auth.signUp(email: email, password: password)
            
//            let userID = signUpResponse.user.id
            
            let userRole = UserRole(user_id: signUpResponse.user.id, role_id: roleID)
            try await supabase
                .from("user_roles")
                .insert(userRole)
                .execute()
            
            let genPass = GenPass(user_id: signUpResponse.user.id)
            try await supabase
                .from("gen_pass")
                .insert(genPass)
                .execute()
            let text = "Your Login Crediets as \(role) are as follows:\nPassword: \(password)"
            sendEmail(toName: name, toEmail: email, subject: "Welcome to Fleet Management System", text: text)
            
            print("User signed up successfully with role: \(role)")
            
            return signUpResponse.user.id
        } catch {
            print("Error during sign-up: \(error.localizedDescription)")
            return nil
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
                        self.session = session
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
                    saveUserDefaults()
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
                saveUserDefaults()
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
                await MainActor.run {
                    authError = "Login failed: \(error.localizedDescription)"
                    alertMessage = authError!
                    showAlert = true
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                
                UserDefaults.standard.removeObject(forKey: "accessToken")
                UserDefaults.standard.removeObject(forKey: "refreshToken")
                UserDefaults.standard.synchronize() // Ensure changes are saved
                
                await MainActor.run {
                    self.userRole = nil
                    self.isAuthenticated = false
                    self.userID = nil
                    self.isGenPass = false
                    self.otpVerified = false
                    self.roleMatched = false
                    self.session = nil
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
    
    func getUserID() async -> UUID? {
        guard let userID = supabase.auth.currentUser?.id else { return nil }
        return userID
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
    
    // MARK: - Manage Crew and Vehicle Record
    func fetchFleetManagerByUserID(userID: UUID) async throws -> FleetManager? {
        do {
            let response = try await supabase
                .from("fleet_manager")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data

            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Fleet Manager: \(rawJSON)")
            }

            // Decode JSON as an array of dictionaries and extract the first record
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No fleet manager found for userID: \(userID)")
                return nil
            }

            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into FleetManager model
            let fleetManager = try decoder.decode(FleetManager.self, from: transformedData)
            print("Decoded Fleet Manager: \(fleetManager)")
            return fleetManager
        } catch {
            print("Error fetching fleet manager: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchFleetManagers() async throws -> [FleetManager] {
        do {
            let response = try await supabase
                .from("fleet_manager")
                .select()
                .eq("isDeleted", value: false)
                .execute()
            
            let data = response.data

            // Decode JSON as an array of dictionaries first
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }

            // Convert transformed array back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into FleetManager model
            let fleetManagers = try decoder.decode([FleetManager].self, from: transformedData)
            print("Decoded Fleet Managers: \(fleetManagers)")
            return fleetManagers
        } catch {
            print("Error fetching fleet managers: \(error)")
            return []
        }
    }
    
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
            for i in 0..<jsonArray.count {
                if let expiryDateString = jsonArray[i]["driverLicenseExpiry"] as? String {
                    // Set up a formatter for the input format "yyyy-MM-dd HH:mm:ss"
                    let inputFormatter = DateFormatter()
                    inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    if let date = inputFormatter.date(from: expiryDateString) {
                        // Configure ISO8601DateFormatter to include fractional seconds
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let formattedDate = isoFormatter.string(from: date)
                        
                        // Update the JSON with the properly formatted date string
                        jsonArray[i]["driverLicenseExpiry"] = formattedDate
                    }
                }
            }
            
            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])
            
            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
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
    
    func fetchDrivers() async throws -> [Driver] {
        do {
            let response = try await supabase
                .from("driver")
                .select()
                .eq("isDeleted", value: false)
                .execute()
            
            let data = response.data

            // Decode JSON as an array of dictionaries first
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }

            // Fix date format for driverLicenseExpiry
            for i in 0..<jsonArray.count {
                if let expiryDateString = jsonArray[i]["driverLicenseExpiry"] as? String {
                    // Set up a formatter for the input format "yyyy-MM-dd HH:mm:ss"
                    let inputFormatter = DateFormatter()
                    inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    if let date = inputFormatter.date(from: expiryDateString) {
                        // Configure ISO8601DateFormatter to include fractional seconds
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let formattedDate = isoFormatter.string(from: date)
                        
                        // Update the JSON with the properly formatted date string
                        jsonArray[i]["driverLicenseExpiry"] = formattedDate
                    }
                }
            }

            // Convert transformed array back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Allows fractional seconds
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into Driver model
            let drivers = try decoder.decode([Driver].self, from: transformedData)
//            print("Decoded Drivers: \(drivers)")
            return drivers
        } catch {
            print("Error fetching drivers: \(error)")
            return []
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
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
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
    
    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel] {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .eq("isDeleted", value: false)
                .execute()
            
            let data = response.data

            // Custom Date Formatter
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Fractional seconds support
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode data
            let personnels = try decoder.decode([MaintenancePersonnel].self, from: data)
            return personnels
        } catch {
            print("Error fetching maintenance personnel: \(error)")
            return []
        }
    }

    func insertDriver(driver: Driver, password: String) async throws {
        do {
            // Set up a custom JSONEncoder with ISO8601 format including milliseconds.
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the driver to JSON for debugging/logging.
            let driverJSONData = try encoder.encode(driver)
            if let driverJSONString = String(data: driverJSONData, encoding: .utf8) {
                print("Driver JSON to insert: \(driverJSONString)")
            }
            
            // Insert the driver into the "driver" table.
            let response = try await supabase
                .from("driver")
                .insert(driver)
                .execute()
            
            // Print raw JSON response for debugging.
            if let rawJSON = String(data: response.data, encoding: .utf8) {
                print("Raw JSON Insert Response for Driver: \(rawJSON)")
            }
            
            print("Insert response: \(response)")
            
        } catch {
            print("Error inserting driver: \(error.localizedDescription)")
            throw error
        }
    }
    
    func insertMaintenancePersonnel(personnel: MaintenancePersonnel, password: String) async throws {
        do {
            // Set up a custom JSONEncoder with ISO8601 format including milliseconds.
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the personnel to JSON for debugging/logging.
            let personnelJSONData = try encoder.encode(personnel)
            if let personnelJSONString = String(data: personnelJSONData, encoding: .utf8) {
                print("Maintenance Personnel JSON to insert: \(personnelJSONString)")
            }
            
            // Insert the personnel record into the "maintenance_personnel" table.
            let response = try await supabase
                .from("maintenance_personnel")
                .insert(personnel)
                .execute()
            
            // Print raw JSON response for debugging.
            if let rawJSON = String(data: response.data, encoding: .utf8) {
                print("Raw JSON Insert Response for Maintenance Personnel: \(rawJSON)")
            }
            
            print("Insert response: \(response)")
            
        } catch {
            print("Error inserting maintenance personnel: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchVehicles() async throws -> [Vehicle] {
        do {
            let response = try await supabase
                .from("vehicles")
                .select()
                .notEquals("status", value: "Decommissioned")
                .execute()
            
            let data = response.data
            
            // Decode JSON as an array of dictionaries first.
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }
            
            // Set up input formatter for "yyyy-MM-dd"
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd"
            inputFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            // Set up output formatter for "yyyy-MM-dd" (you can change this if needed)
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd"
            outputFormatter.locale = Locale(identifier: "en_US_POSIX")
            outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Fix date format for pollution_expiry and insurance_expiry fields.
            for i in 0..<jsonArray.count {
                // Convert pollution_expiry from string to Date and back to formatted string.
                if let pollutionExpiryString = jsonArray[i]["pollution_expiry"] as? String,
                   let pollutionDate = inputFormatter.date(from: pollutionExpiryString) {
                    let formattedPollutionExpiry = outputFormatter.string(from: pollutionDate)
                    jsonArray[i]["pollution_expiry"] = formattedPollutionExpiry
                }
                
                // Convert insurance_expiry from string to Date and back to formatted string.
                if let insuranceExpiryString = jsonArray[i]["insurance_expiry"] as? String,
                   let insuranceDate = inputFormatter.date(from: insuranceExpiryString) {
                    let formattedInsuranceExpiry = outputFormatter.string(from: insuranceDate)
                    jsonArray[i]["insurance_expiry"] = formattedInsuranceExpiry
                }
            }
            
            // Convert the transformed JSON array back to Data.
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])
            
            // Create a date formatter for decoding dates from JSON.
            let decoderDateFormatter = DateFormatter()
            decoderDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            decoderDateFormatter.dateFormat = "yyyy-MM-dd"
            decoderDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(decoderDateFormatter)
            
            // Decode into Vehicle model
            let vehicles = try decoder.decode([Vehicle].self, from: transformedData)
//            print("Decoded Vehicles: \(vehicles)")
            return vehicles
        } catch {
            print("Error fetching vehicles: \(error)")
            return []
        }
    }

    func updateDriverStatus(newStatus: Status, for userID: UUID) async {
        // Use [String: String] since newStatus.rawValue is a String.
        let payload: [String: String] = ["status": newStatus.rawValue]
        
        do {
            let response = try await supabase
                .from("driver")
                .update(payload)
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            let jsonString = String(data: data, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func updateMaintenancePersonnelStatus(newStatus: Status, for userID: UUID) async {
        // Use [String: String] since newStatus.rawValue is a String.
        print(newStatus)
        let payload: [String: String] = ["status": newStatus.rawValue]
        
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .update(payload)
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            let jsonString = String(data: data, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func softDeleteDriver(for userID: UUID) async {
        do {
        let response = try await supabase
            .from("driver")
            .update(["isDeleted": true])
            .eq("id", value: userID)
            .execute()
        
        let data = response.data
        let jsonString = String(data: data, encoding: .utf8)
        print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func softDeleteMaintenancePersonnel(for userID: UUID) async {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .update(["isDeleted": true])
                .eq("id", value: userID)
                .execute()
            
            let data = response.data
            let jsonString = String(data: data, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func updateDriver(driver: Driver) async {
        do {
        let response = try await supabase
            .from("driver")
            .update(driver)
            .eq("id", value: driver.id)
            .execute()
        
        let data = response.data
        let jsonString = String(data: data, encoding: .utf8)
        print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func updateMaintenancePersonnel(personnel: MaintenancePersonnel) async {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .update(personnel)
                .eq("id", value: personnel.id)
                .execute()
            
            let data = response.data
            let jsonString = String(data: data, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func insertVehicle(vehicle: Vehicle) async throws {
        // 1. Create a date formatter for encoding date fields as "yyyy-MM-dd"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 2. Convert your `Vehicle`'s dates to strings
        let pollutionExpiryString = dateFormatter.string(from: vehicle.pollutionExpiry)
        let insuranceExpiryString = dateFormatter.string(from: vehicle.insuranceExpiry)

        // 3. Convert document `Data` fields to Base64 strings (if they exist)
        let pollutionCertBase64 = vehicle.documents?.pollutionCertificate?.base64EncodedString()
        let rcBase64 = vehicle.documents?.rc?.base64EncodedString()
        let insuranceBase64 = vehicle.documents?.insurance?.base64EncodedString()

        // 5. Create an instance of the payload
        let payload = VehiclePayload(
            id: vehicle.id,
            name: vehicle.name,
            year: vehicle.year,
            make: vehicle.make,
            model: vehicle.model,
            vin: vehicle.vin,
            license_plate: vehicle.licensePlate,
            vehicle_type: vehicle.vehicleType,
            color: vehicle.color,
            body_type: vehicle.bodyType,
            body_subtype: vehicle.bodySubtype,
            msrp: vehicle.msrp,
            pollution_expiry: pollutionExpiryString,
            insurance_expiry: insuranceExpiryString,
            status: vehicle.status,
            driver_id: vehicle.driverId,
            pollution_certificate: pollutionCertBase64,
            rc: rcBase64,
            insurance: insuranceBase64
        )

        do {
            // 6. Insert the payload into Supabase
            let response = try await supabase
                .from("vehicles")
                .insert([payload])
                .execute()
            
            print("Insert success: \(response)")
        } catch {
            print("Error inserting vehicle: \(error.localizedDescription)")
        }
    }

    func updateVehicle(vehicle: Vehicle) async throws {
        // 1. Create a date formatter for encoding date fields as "yyyy-MM-dd"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 2. Convert your `Vehicle`'s dates to strings
        let pollutionExpiryString = dateFormatter.string(from: vehicle.pollutionExpiry)
        let insuranceExpiryString = dateFormatter.string(from: vehicle.insuranceExpiry)

        // 3. Convert document `Data` fields to Base64 strings (if they exist)
        let pollutionCertBase64 = vehicle.documents?.pollutionCertificate?.base64EncodedString()
        let rcBase64 = vehicle.documents?.rc?.base64EncodedString()
        let insuranceBase64 = vehicle.documents?.insurance?.base64EncodedString()

        // 5. Create an instance of the update payload with current vehicle details.
        let payload = VehiclePayload(
            id: vehicle.id,
            name: vehicle.name,
            year: vehicle.year,
            make: vehicle.make,
            model: vehicle.model,
            vin: vehicle.vin,
            license_plate: vehicle.licensePlate,
            vehicle_type: vehicle.vehicleType,
            color: vehicle.color,
            body_type: vehicle.bodyType,
            body_subtype: vehicle.bodySubtype,
            msrp: vehicle.msrp,
            pollution_expiry: pollutionExpiryString,
            insurance_expiry: insuranceExpiryString,
            status: vehicle.status,
            driver_id: vehicle.driverId,
            pollution_certificate: pollutionCertBase64,
            rc: rcBase64,
            insurance: insuranceBase64
        )

        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update([payload])
                .eq("id", value: vehicle.id)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error.localizedDescription)")
        }
    }

    func softDeleteVehichle(vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["status": "Decommissioned"])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
    
    func updateVehichleStatus(newStatus: VehicleStatus, vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["status": newStatus.rawValue])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
}
