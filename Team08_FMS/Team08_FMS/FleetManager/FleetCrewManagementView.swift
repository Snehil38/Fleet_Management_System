//
//  FleetCrewManagementView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

//@_exported import Team08_FMS

struct FleetCrewManagementView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @State private var crewType: CrewType = .drivers
    @State private var showingAddDriverSheet = false
    @State private var showingAddMaintenanceSheet = false
    @State private var searchText = ""
    @State private var selectedStatus: Status?  // Updated to use our new Status enum

    // We now filter on any crew member conforming to CrewMemberProtocol.
    var filteredCrew: [any CrewMemberProtocol] {
        let crewList: [any CrewMemberProtocol] = crewType == .drivers ? dataManager.drivers : dataManager.maintenancePersonnel
        return crewList.filter { crew in
            let matchesSearch = searchText.isEmpty ||
                crew.name.lowercased().contains(searchText.lowercased())
            let matchesStatus = selectedStatus == nil || crew.status == selectedStatus
            return matchesSearch && matchesStatus
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search crew members...", text: $searchText)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Crew Type Selector
                    Picker("Crew Type", selection: $crewType) {
                        Text("Drivers").tag(CrewType.drivers)
                        Text("Maintenance Personnel").tag(CrewType.maintenancePersonnel)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Status Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedStatus == nil,
                                action: { selectedStatus = nil }
                            )
                            
                            ForEach([Status.available, .busy, .offDuty], id: \.self) { status in
                                FilterChip(
                                    title: AppDataController.shared.getStatusString(status: status),
                                    isSelected: selectedStatus == status,
                                    action: { selectedStatus = status }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // Crew List
                    LazyVStack(spacing: 16) {
                        if filteredCrew.isEmpty {
                            EmptyStateView(type: crewType)
                        } else {
                            ForEach(filteredCrew, id: \.id) { crew in
                                CrewCardView(crewMember: crew)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Crew Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            if crewType == .drivers {
                                showingAddDriverSheet = true
                            } else {
                                showingAddMaintenanceSheet = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDriverSheet) {
                AddDriverView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAddMaintenanceSheet) {
                AddMaintenancePersonnelView()
                    .environmentObject(dataManager)
            }
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
    let type: CrewType

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No \(type == .drivers ? "drivers" : "maintenance personnel") found")
                .font(.headline)
            Text("Add new crew members or try different filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct CrewCardView: View {
    let crewMember: any CrewMemberProtocol
    @EnvironmentObject var dataManager: CrewDataController
    @State private var showingDeleteAlert = false
    @State private var showingMessageSheet = false
    @State private var unreadMessageCount = 0
    
    // This computed property returns the most recent crew member from the data manager.
    var currentCrew: any CrewMemberProtocol {
        if crewMember is Driver {
            return dataManager.drivers.first { $0.id == crewMember.id } ?? crewMember
        } else {
            return dataManager.maintenancePersonnel.first { $0.id == crewMember.id } ?? crewMember
        }
    }
    
    // Helper to get the userID safely
    private var recipientId: UUID? {
        if let driver = currentCrew as? Driver {
            return driver.userID
        }
        return nil
    }
    
    // Check if driver is in a trip
    private var isInTrip: Bool {
        guard let driver = currentCrew as? Driver else { return false }
        return driver.status == .busy
    }
    
    var body: some View {
        NavigationLink(destination: CrewProfileView(crewMember: currentCrew)) {
            VStack(spacing: 0) {
                // Header with name and status
                HStack {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(currentCrew.name.prefix(2)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(currentCrew.name)
                                .font(.headline)
                            Text(crewMember is Driver ? "Driver" : "Maintenance")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Message button
                    Button {
                        showingMessageSheet = true
                    } label: {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(recipientId == nil)
                    
                    // Status indicator
                    Text(AppDataController.shared.getStatusString(status: currentCrew.status))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(currentCrew.status.backgroundColor)
                        .foregroundColor(currentCrew.status.color)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingMessageSheet) {
            if let recipientId = recipientId {
                NavigationView {
                    ChatView(
                        recipientType: crewMember is Driver ? .driver : .maintenance,
                        recipientId: recipientId,
                        recipientName: currentCrew.name,
                        tripId: (currentCrew as? Driver)?.currentTripId
                    )
                }
            }
        }
    }
}

struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 110, height: 100)
        .background(isSelected ? color.opacity(0.1) : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
    }
}
