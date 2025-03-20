//
//  VehiclesView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

private struct VehicleCard: View {
    let vehicle: Vehicle
    let vehicleManager: VehicleManager
    @State private var showingDeleteAlert = false
    @State private var showingOptions = false

    private var statusColor: Color {
        switch vehicle.status {
        case .available: return .green
        case .inService: return .blue
        case .underMaintenance: return .orange
        case .decommissioned: return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with vehicle name and status
            HStack {
                Text(vehicle.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(vehicle.status.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top)

            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Vehicle basic info
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label("\(vehicle.year)", systemImage: "car.fill")
                            .foregroundColor(.secondary)
                        Text("\(vehicle.make) \(vehicle.model)")
                            .foregroundColor(.primary)
                    }

                    Divider()

                    VStack(alignment: .leading) {
                        Label("License", systemImage: "creditcard.fill")
                            .foregroundColor(.secondary)
                        Text(vehicle.licensePlate)
                            .foregroundColor(.primary)
                    }
                }

                Divider()

                // Vehicle details
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label("Type", systemImage: "tag.fill")
                            .foregroundColor(.secondary)
                        Text("\(vehicle.bodyType.rawValue) - \(vehicle.bodySubtype)")
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if !vehicle.color.isEmpty {
                        VStack(alignment: .leading) {
                            Label("Color", systemImage: "paintpalette.fill")
                                .foregroundColor(.secondary)
                            Text(vehicle.color)
                                .foregroundColor(.primary)
                        }
                    }
                }

                // Document status indicators
                HStack(spacing: 12) {
                    Label("RC", systemImage: vehicle.documents?.rc != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(vehicle.documents?.rc != nil ? .green : .red)

                    Label("Insurance", systemImage: vehicle.documents?.insurance != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(vehicle.documents?.insurance != nil ? .green : .red)

                    Label("Pollution", systemImage: vehicle.documents?.pollutionCertificate != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(vehicle.documents?.pollutionCertificate != nil ? .green : .red)
                }
                .font(.caption)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Vehicle", systemImage: "trash")
            }

            if vehicle.status != .underMaintenance {
                Button {
                    vehicleManager.markVehicleForMaintenance(vehicleId: vehicle.id)
                } label: {
                    Label("Mark for Maintenance", systemImage: "wrench.fill")
                }
            }

            if vehicle.status != .available {
                Button {
                    vehicleManager.markVehicleAsIdle(vehicleId: vehicle.id)
                } label: {
                    Label("Mark as Idle", systemImage: "checkmark.circle.fill")
                }
            }

            Button {
                // Add share functionality here
                showingOptions = true
            } label: {
                Label("Share Details", systemImage: "square.and.arrow.up")
            }
        }
        .alert("Delete Vehicle", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                vehicleManager.deleteVehicle(vehicle)
            }
        } message: {
            Text("Are you sure you want to delete this vehicle? This action cannot be undone.")
        }
    }
}

private struct VehicleListView: View {
    let vehicles: [Vehicle]
    let vehicleManager: VehicleManager

    var body: some View {
        LazyVStack(spacing: 16) {
            if vehicles.isEmpty {
                EmptyStateView()
            } else {
                ForEach(vehicles) { vehicle in
                    NavigationLink(destination: VehicleDetailView(vehicle: vehicle, vehicleManager: vehicleManager)) {
                        VehicleCard(vehicle: vehicle, vehicleManager: vehicleManager)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

private struct SearchBarView: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search vehicles...", text: $searchText)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

private struct StatusFilterView: View {
    @Binding var selectedStatus: VehicleStatus?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: selectedStatus == nil,
                    action: { selectedStatus = nil }
                )
                
                ForEach(VehicleStatus.allValues, id: \.self) { status in
                    FilterChip(
                        title: status.rawValue.capitalized,
                        isSelected: selectedStatus == status,
                        action: { selectedStatus = status }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// Add this new view for deletion mode
private struct DeleteVehiclesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vehicleManager: VehicleManager
    @State private var selectedVehicles = Set<UUID>()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationView {
            List {
                ForEach(vehicleManager.vehicles) { vehicle in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vehicle.name)
                                .font(.headline)
                            Text("\(vehicle.make) \(vehicle.model)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(vehicle.licensePlate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: selectedVehicles.contains(vehicle.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedVehicles.contains(vehicle.id) ? .accentColor : .secondary)
                            .font(.title2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedVehicles.contains(vehicle.id) {
                            selectedVehicles.remove(vehicle.id)
                        } else {
                            selectedVehicles.insert(vehicle.id)
                        }
                    }
                }
            }
            .navigationTitle("Delete Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete Selected") {
                        showingConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(selectedVehicles.isEmpty)
                }
            }
            .alert("Delete Vehicles", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    for id in selectedVehicles {
                        if let vehicle = vehicleManager.vehicles.first(where: { $0.id == id }) {
                            vehicleManager.deleteVehicle(vehicle)
                        }
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedVehicles.count) vehicle\(selectedVehicles.count == 1 ? "" : "s")? This action cannot be undone.")
            }
        }
    }
}

struct VehiclesView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @EnvironmentObject private var vehicleManager: VehicleManager
    @State private var showingAddVehicle = false
    @State private var showingDeleteMode = false
    @State private var showingProfile = false
    @State private var showingMessages = false
    @State private var searchText = ""
    @State private var selectedStatus: VehicleStatus?

    private func matchesSearch(_ vehicle: Vehicle) -> Bool {
        guard !searchText.isEmpty else { return true }
        let searchText = self.searchText.lowercased()

        return vehicle.name.lowercased().contains(searchText) ||
               vehicle.make.lowercased().contains(searchText) ||
               vehicle.model.lowercased().contains(searchText) ||
               vehicle.licensePlate.lowercased().contains(searchText)
    }

    private var filteredVehicles: [Vehicle] {
        let vehicles = vehicleManager.getVehiclesByStatus(selectedStatus)
        return vehicles.filter(matchesSearch)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    SearchBarView(searchText: $searchText)
                    StatusFilterView(selectedStatus: $selectedStatus)
                    VehicleListView(vehicles: filteredVehicles, vehicleManager: vehicleManager)
                }
                .padding(.vertical)
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingAddVehicle = true }) {
                            Image(systemName: "plus")
                        }
//                        Button {
//                            showingMessages = true
//                        } label: {
//                            Image(systemName: "message.fill")
//                                .foregroundColor(.blue)
//                        }
//
//                        Button {
//                            showingProfile = true
//                        } label: {
//                            Image(systemName: "person.circle.fill")
//                                .foregroundColor(.blue)
//                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationView {
                    FleetManagerProfileView()
                        .environmentObject(dataManager)
                }
            }
            .sheet(isPresented: $showingMessages) {
                NavigationView {
                    ContactView()
                        .environmentObject(dataManager)
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                VehicleDetailView(vehicleManager: vehicleManager)
            }
//            .sheet(isPresented: $showingDeleteMode) {
//                DeleteVehiclesView(vehicleManager: vehicleManager)
//            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No vehicles found")
                .font(.headline)
            Text("Add a new vehicle or try different filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
