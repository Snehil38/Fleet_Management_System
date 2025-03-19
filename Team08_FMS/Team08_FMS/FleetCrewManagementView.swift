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
    @State private var currentPage = 1
    @State private var itemsPerPage = 6
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var selectedStatusFilter: CrewMember.Status? = nil

    var filteredCrew: [CrewMember] {
        let crewList = crewType == .drivers ? dataManager.drivers : dataManager.maintenancePersonnel

        return crewList.filter { crewMember in
            // Filter by search text
            let matchesSearch = searchText.isEmpty ||
                crewMember.name.lowercased().contains(searchText.lowercased())

            // Filter by status
            let matchesStatus = selectedStatusFilter == nil || crewMember.status == selectedStatusFilter

            return matchesSearch && matchesStatus
        }
    }

    var pagedCrew: [CrewMember] {
        let startIndex = (currentPage - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredCrew.count)

        if startIndex >= filteredCrew.count {
            return []
        }

        return Array(filteredCrew[startIndex..<endIndex])
    }

    var totalPages: Int {
        return max(1, Int(ceil(Double(filteredCrew.count) / Double(itemsPerPage))))
    }

    var statusCounts: (available: Int, busy: Int, offline: Int) {
        let crewList = crewType == .drivers ? dataManager.drivers : dataManager.maintenancePersonnel
        let available = crewList.filter { $0.status == .available }.count
        let busy = crewList.filter { $0.status == .busy }.count
        let offline = crewList.filter { $0.status == .offline }.count
        return (available, busy, offline)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Summary Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatusCard(
                            title: "Available",
                            count: statusCounts.available,
                            color: .green,
                            icon: "checkmark.circle.fill",
                            isSelected: selectedStatusFilter == .available
                        )
                        .onTapGesture {
                            if selectedStatusFilter == .available {
                                selectedStatusFilter = nil
                            } else {
                                selectedStatusFilter = .available
                            }
                            currentPage = 1
                        }

                        StatusCard(
                            title: "Busy",
                            count: statusCounts.busy,
                            color: .yellow,
                            icon: "clock.fill",
                            isSelected: selectedStatusFilter == .busy
                        )
                        .onTapGesture {
                            if selectedStatusFilter == .busy {
                                selectedStatusFilter = nil
                            } else {
                                selectedStatusFilter = .busy
                            }
                            currentPage = 1
                        }

                        StatusCard(
                            title: "Offline",
                            count: statusCounts.offline,
                            color: .red,
                            icon: "xmark.circle.fill",
                            isSelected: selectedStatusFilter == .offline
                        )
                        .onTapGesture {
                            if selectedStatusFilter == .offline {
                                selectedStatusFilter = nil
                            } else {
                                selectedStatusFilter = .offline
                            }
                            currentPage = 1
                        }

                        StatusCard(
                            title: "Total",
                            count: statusCounts.available + statusCounts.busy + statusCounts.offline,
                            color: .blue,
                            icon: "person.3.fill",
                            isSelected: selectedStatusFilter == nil
                        )
                        .onTapGesture {
                            selectedStatusFilter = nil
                            currentPage = 1
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Segmented Control
                Picker("Crew Type", selection: $crewType) {
                    Text("Drivers").tag(CrewType.drivers)
                    Text("Maintenance Personnel").tag(CrewType.maintenance)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: crewType) { _ in
                    // Reset to page 1 when switching crew types
                    currentPage = 1
                    selectedStatusFilter = nil
                }

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search by name", text: $searchText)
                        .onChange(of: searchText) { _ in
                            // Reset to page 1 when search text changes
                            currentPage = 1
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }

                    Divider()
                        .frame(height: 20)

                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                }
                .padding(8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Results count
                HStack {
                    Text("\(filteredCrew.count) \(crewType == .drivers ? "Drivers" : "Maintenance Personnel")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if selectedStatusFilter != nil {
                        Button(action: {
                            selectedStatusFilter = nil
                        }) {
                            HStack {
                                Text("Clear Filter")
                                    .font(.subheadline)
                                Image(systemName: "xmark")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    // Crew Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                        if pagedCrew.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)

                                Text("No \(crewType == .drivers ? "drivers" : "maintenance personnel") found")
                                    .foregroundColor(.secondary)

                                if !searchText.isEmpty || selectedStatusFilter != nil {
                                    Button(action: {
                                        searchText = ""
                                        selectedStatusFilter = nil
                                    }) {
                                        Text("Clear all filters")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(pagedCrew) { crewMember in
                                CrewCardView(crewMember: crewMember)
                            }
                        }
                    }
                    .padding()

                    // Pagination UI
                    if totalPages > 1 {
                        HStack(spacing: 16) {
                            Button(action: {
                                if currentPage > 1 {
                                    currentPage -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentPage > 1 ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(currentPage > 1 ? .white : .gray)
                                .cornerRadius(8)
                            }
                            .disabled(currentPage <= 1)

                            // Page indicator
                            VStack(spacing: 4) {
                                Text("Page \(currentPage) of \(totalPages)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Page dots
                                HStack(spacing: 8) {
                                    ForEach(1...min(totalPages, 5), id: \.self) { page in
                                        Circle()
                                            .fill(page == currentPage ? Color.blue : Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }

                                    if totalPages > 5 {
                                        Text("...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Button(action: {
                                if currentPage < totalPages {
                                    currentPage += 1
                                }
                            }) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentPage < totalPages ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(currentPage < totalPages ? .white : .gray)
                                .cornerRadius(8)
                            }
                            .disabled(currentPage >= totalPages)
                        }
                        .padding()
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("Crew Management")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button(action: {
                    // Export or generate report action
                    // This would typically generate a PDF or CSV of the crew data
                }) {
                    Image(systemName: "square.and.arrow.up")
                },
                trailing: Button(action: {
                    if crewType == .drivers {
                        showingAddDriverSheet = true
                    } else {
                        showingAddMaintenanceSheet = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingAddDriverSheet) {
                AddDriverView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAddMaintenanceSheet) {
                AddMaintenancePersonnelView()
                    .environmentObject(dataManager)
            }
            .actionSheet(isPresented: $showingFilterSheet) {
                ActionSheet(
                    title: Text("Filter Crew"),
                    message: Text("Select status to filter by"),
                    buttons: [
                        .default(Text("All")) { selectedStatusFilter = nil },
                        .default(Text("Available")) { selectedStatusFilter = .available },
                        .default(Text("Busy")) { selectedStatusFilter = .busy },
                        .default(Text("Offline")) { selectedStatusFilter = .offline },
                        .cancel()
                    ]
                )
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

struct CrewCardView: View {
    let crewMember: CrewMember
    @State private var showingProfile = false
    @State private var showingActionSheet = false

    var body: some View {
        Button(action: {
            showingProfile = true
        }) {
            VStack(spacing: 0) {
                // Card Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 48, height: 48)

                        Text(crewMember.avatar)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading) {
                        Text(crewMember.name)
                            .font(.headline)
                        Text("\(crewMember.role) • ID: \(crewMember.id)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Menu {
                        Button(action: {
                            showingProfile = true
                        }) {
                            Label("View Profile", systemImage: "person.crop.circle")
                        }

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

                    Text(crewMember.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(crewMember.status.backgroundColor)
                        .foregroundColor(crewMember.status.color)
                        .cornerRadius(4)
                }
                .padding()

                Divider()

                // Card Details
                VStack(spacing: 8) {
                    ForEach(crewMember.details) { detail in
                        HStack {
                            Text(detail.label + ":")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(detail.value)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()

                // View indicator at bottom
                HStack {
                    Spacer()
                    Text("Tap to view profile")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
}
