//
//  AppDataModel.swift
//  Team08_FMS
//
//  Created by Swarn Singh Chauhan on 19/03/25.
//

import Foundation
import Foundation

// MARK: - App Data Model
struct AppDataModel {
    // Users of the fleet management system
    //var users: [User] = []
    var drivers:[Driver] = []
    var maintenancePersonnel:[MaintenancePersonnel] = []
    
    // Vehicles in the fleet
    var vehicles: [Vehicle] = []
    
    // Trips or assignments
    var trips: [Trip] = []
    
    // Maintenance records for vehicles
    var maintenanceRecords: [MaintenanceRecord] = []
    
    // Notifications for various events
    var notifications: [NotificationItem] = []
    
    // Global settings for the app
    var settings: AppSettings = AppSettings(defaultOperatingHours: "08:00 - 18:00", supportContact: "support@example.com")
}

