import Foundation

class VehicleManager: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    private let vehiclesKey = "savedVehicles"

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

    private func loadVehicles() {
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decodedVehicles = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decodedVehicles
        }
    }

    private func saveVehicles() {
        if let encoded = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(encoded, forKey: vehiclesKey)
        }
    }

    func addVehicle(name: String, year: Int, make: String, model: String, vin: String, licensePlate: String, vehicleType: VehicleType, color: String, bodyType: BodyType, bodySubtype: String, msrp: Double, pollutionExpiry: Date, insuranceExpiry: Date, documents: VehicleDocuments) {
        let newVehicle = Vehicle(
            id: UUID(),
            name: name,
            year: year,
            make: make,
            model: model,
            vin: vin,
            licensePlate: licensePlate,
            vehicleType: vehicleType,
            color: color,
            bodyType: bodyType,
            bodySubtype: bodySubtype,
            msrp: msrp,
            pollutionExpiry: pollutionExpiry,
            insuranceExpiry: insuranceExpiry,
            status: .available,
            driverId: nil,
            documents: documents
        )
        vehicles.append(newVehicle)
        saveVehicles()
    }

    func updateVehicle(_ vehicle: Vehicle, name: String, year: Int, make: String, model: String, vin: String, licensePlate: String, vehicleType: VehicleType, color: String, bodyType: BodyType, bodySubtype: String, msrp: Double, pollutionExpiry: Date, insuranceExpiry: Date, documents: VehicleDocuments) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            let updatedVehicle = Vehicle(
                id: vehicle.id,
                name: name,
                year: year,
                make: make,
                model: model,
                vin: vin,
                licensePlate: licensePlate,
                vehicleType: vehicleType,
                color: color,
                bodyType: bodyType,
                bodySubtype: bodySubtype,
                msrp: msrp,
                pollutionExpiry: pollutionExpiry,
                insuranceExpiry: insuranceExpiry,
                status: vehicle.status,
                driverId: vehicle.driverId,
                documents: documents
            )
            vehicles[index] = updatedVehicle
            saveVehicles()
        }
    }

    func deleteVehicle(_ vehicle: Vehicle) {
        vehicles.removeAll { $0.id == vehicle.id }
        saveVehicles()
    }

    func getVehiclesByStatus(_ status: VehicleStatus?) -> [Vehicle] {
        if let status = status {
            return vehicles.filter { $0.status == status }
        }
        return vehicles
    }

    // MARK: - Status Management

    func assignDriverToVehicle(vehicleId: UUID, driverId: UUID) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            var vehicle = vehicles[index]
            vehicle.driverId = driverId
            vehicle.status = .inService
            vehicles[index] = vehicle
            saveVehicles()
        }
    }

    func removeDriverFromVehicle(vehicleId: UUID) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            var vehicle = vehicles[index]
            vehicle.driverId = nil
            vehicle.status = .available
            vehicles[index] = vehicle
            saveVehicles()
        }
    }

    func markVehicleForMaintenance(vehicleId: UUID) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            var vehicle = vehicles[index]
            vehicle.status = .underMaintenance
            vehicles[index] = vehicle
            saveVehicles()
        }
    }

    func markVehicleAsIdle(vehicleId: UUID) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicleId }) {
            var vehicle = vehicles[index]
            vehicle.status = .available
            vehicles[index] = vehicle
            saveVehicles()
        }
    }
}
