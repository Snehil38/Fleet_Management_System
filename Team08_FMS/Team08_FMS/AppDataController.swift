//
//  AppDataController.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import Foundation

class AppDataController: ObservableObject {
    static let shared = AppDataController()
    
    private init() {}
    
    @Published var isAuthenticated: Bool = false
    @Published var userRole: UserRole = .fleetManager
    
    func randomPasswordGenerator(length: Int) -> String {
        let character = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        return String((0..<length).map { _ in character.randomElement()! })
    }
    
    func logout() {
        // Clear any user data or tokens here
        isAuthenticated = false
        userRole = .fleetManager
        
        // If you're using UserDefaults, clear them
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userRole")
        
        // If you're using Supabase or another backend, sign out there too
        // await supabase.auth.signOut()
    }
}
