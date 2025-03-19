//
//  FleetCrewManagementView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

struct CrewMember: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let role: String
    let status: Status
    let details: [DetailItem]

    enum Status: String {
        case available = "Available"
        case busy = "Busy"
        case offline = "Offline"

        var color: Color {
            switch self {
            case .available: return Color.green
            case .busy: return Color.yellow
            case .offline: return Color.red
            }
        }

        var backgroundColor: Color {
            switch self {
            case .available: return Color.green.opacity(0.2)
            case .busy: return Color.yellow.opacity(0.2)
            case .offline: return Color.red.opacity(0.2)
            }
        }
    }
}

struct DetailItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

enum CrewType {
    case drivers
    case maintenance
}

struct FleetCrewManagementView: View {
    @EnvironmentObject private var dataManager: CrewDataManager
    @State private var crewType: CrewType = .drivers
    @State private var showingAddDriverSheet = false
    @State private var showingAddMaintenanceSheet = false
    @State private var searchText = ""
    @State private var selectedStatus: CrewMember.Status?

    var filteredCrew: [CrewMember] {
        let crewList = crewType == .drivers ? dataManager.drivers : dataManager.maintenancePersonnel
        return crewList.filter { crewMember in
            let matchesSearch = searchText.isEmpty ||
                crewMember.name.lowercased().contains(searchText.lowercased())
            let matchesStatus = selectedStatus == nil || crewMember.status == selectedStatus
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
                        Text("Maintenance Personnel").tag(CrewType.maintenance)
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

                            ForEach([CrewMember.Status.available, .busy, .offline], id: \.self) { status in
                                FilterChip(
                                    title: status.rawValue,
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
                            ForEach(filteredCrew) { crewMember in
                                CrewCardView(crewMember: crewMember)
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
                    Button(action: {
                        if crewType == .drivers {
                            showingAddDriverSheet = true
                        } else {
                            showingAddMaintenanceSheet = true
                        }
                    }) {
                        Image(systemName: "plus")
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

struct CrewCardView: View {
    let crewMember: CrewMember
    @State private var showingProfile = false
    @State private var showingActionSheet = false

    private var statusColor: Color {
        switch crewMember.status {
        case .available: return .green
        case .busy: return .yellow
        case .offline: return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with name and status
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(crewMember.avatar)
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(crewMember.name)
                            .font(.headline)
                        Text(crewMember.role)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text(crewMember.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            .padding()
            
            Divider()
            
            // Details section
            VStack(spacing: 12) {
                ForEach(crewMember.details) { detail in
                    HStack(spacing: 16) {
                        Label {
                            Text(detail.label)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: iconForDetail(detail.label))
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text(detail.value)
                            .foregroundColor(.primary)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            
            Divider()
            
            // Footer with actions
            HStack {
                Button(action: {
                    showingProfile = true
                }) {
                    Label("View Profile", systemImage: "person.circle")
                        .font(.subheadline)
                }
                
                Spacer()
                
                Menu {
                    Button(action: {
                        // Assign task action
                    }) {
                        Label("Assign Task", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        // Message action
                    }) {
                        Label("Send Message", systemImage: "message")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        showingActionSheet = true
                    }) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                CrewProfileView(crewMember: crewMember)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Remove \(crewMember.name)"),
                message: Text("Are you sure you want to remove this crew member? This action cannot be undone."),
                buttons: [
                    .destructive(Text("Remove")) {
                        // Remove crew member action
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func iconForDetail(_ label: String) -> String {
        switch label {
        case "Experience":
            return "clock.fill"
        case "License":
            return "car.fill"
        case "Phone":
            return "phone.fill"
        case "Email":
            return "envelope.fill"
        case "Specialty":
            return "wrench.fill"
        case "Certification":
            return "checkmark.seal.fill"
        case "Last Active":
            return "calendar"
        case "Vehicle":
            return "car.fill"
        case "ETA":
            return "timer"
        case "Next Shift":
            return "clock.fill"
        case "Hours This Week":
            return "hourglass"
        case "Location":
            return "location.fill"
        case "Last Job":
            return "briefcase.fill"
        default:
            return "info.circle.fill"
        }
    }
}
