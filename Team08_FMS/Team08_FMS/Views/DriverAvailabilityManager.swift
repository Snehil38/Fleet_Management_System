import SwiftUI

class DriverAvailabilityManager: ObservableObject {
    @Published var isAvailable: Bool = true
    private var lastUnavailableDate: Date?
    
    static let shared = DriverAvailabilityManager()
    
    private init() {}
    
    func canChangeToAvailable() -> Bool {
        guard let lastDate = lastUnavailableDate else { return true }
        return Calendar.current.isDateInToday(lastDate) == false
    }
    
    func setUnavailable() {
        isAvailable = false
        lastUnavailableDate = Date()
    }
} 