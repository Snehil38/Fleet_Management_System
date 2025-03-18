//
//  AppDataController.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import Foundation

class AppDataController {
    static let shared = AppDataController()
    
    private init() {}
    
    func randomPasswordGenerator(length: Int) -> String {
        let character = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        return String((0..<length).map { _ in character.randomElement()! })
    }
}
