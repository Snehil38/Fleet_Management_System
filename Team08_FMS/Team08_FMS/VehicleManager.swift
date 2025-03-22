import Foundation

class VehicleManager: ObservableObject {
    
    static let shared = VehicleManager()
    
    @Published var vehicles: [Vehicle] = []

    init() {
        Task {
            do {
                let vehichle = try await SupabaseDataController.shared.fetchVehicles()
                
                await MainActor.run {
                    vehicles = vehichle
                }
            }
        }
    }

    func loadVehicles() {
        Task {
            do {
                let vehichle = try await SupabaseDataController.shared.fetchVehicles()
                
                await MainActor.run {
                    vehicles = vehichle
                }
            }
        }
    }
}
