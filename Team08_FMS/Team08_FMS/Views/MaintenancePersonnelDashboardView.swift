import SwiftUI

struct MaintenancePersonnelDashboardView: View {
    @StateObject private var dataStore = MaintenancePersonnelDataStore()
    @State private var selectedTab = 0
    @State private var showingNewRequest = false
    @State private var showingContactManager = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Service Requests Tab
                NavigationView {
                    ServiceRequestListView(dataStore: dataStore)
                        .navigationTitle("Service Requests")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingNewRequest = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Requests", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(0)
                
                // Safety Checks Tab
                NavigationView {
                    MaintenancePersonnelSafetyChecksView(dataStore: dataStore)
                        .navigationTitle("Safety Checks")
                }
                .tabItem {
                    Label("Safety", systemImage: "checkmark.shield.fill")
                }
                .tag(1)
                
                // Service History Tab
                NavigationView {
                    MaintenancePersonnelServiceHistoryView(dataStore: dataStore)
                        .navigationTitle("Service History")
                }
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(2)
                
                // Upcoming Services Tab
                NavigationView {
                    MaintenancePersonnelUpcomingServicesView(dataStore: dataStore)
                        .navigationTitle("Upcoming Services")
                }
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(3)
            }
            .sheet(isPresented: $showingNewRequest) {
                NavigationView {
                    MaintenancePersonnelNewServiceRequestView(dataStore: dataStore)
                        .navigationTitle("New Service Request")
                        .navigationBarItems(trailing: Button("Cancel") {
                            showingNewRequest = false
                        })
                }
            }
//            .sheet(isPresented: $showingContactManager) {
//                NavigationView {
//                    ContactFleetManagerView()
//                        .navigationTitle("Contact Fleet Manager")
//                        .navigationBarItems(trailing: Button("Cancel") {
//                            showingContactManager = false
//                        })
//                }
//            }
        }
    }
}

struct ServiceRequestListView: View {
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @State private var searchText = ""
    @State private var selectedStatus: ServiceRequestStatus?
    @State private var selectedRequest: MaintenanceServiceRequest?
    @State private var showingDetail = false
    
    var filteredRequests: [MaintenanceServiceRequest] {
        var requests = dataStore.serviceRequests
        
        if let status = selectedStatus {
            requests = requests.filter { $0.status == status }
        }
        
        if !searchText.isEmpty {
            requests = requests.filter {
                $0.vehicleName.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return requests
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search requests...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ServiceRequestStatus.allCases, id: \.self) { status in
                            StatusFilterButton(
                                status: status,
                                isSelected: selectedStatus == status,
                                action: {
                                    withAnimation {
                                        selectedStatus = selectedStatus == status ? nil : status
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Requests List
            if filteredRequests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No service requests found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Try adjusting your search or filters")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                List(filteredRequests) { request in
                    ServiceRequestRow(request: request)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRequest = request
                            showingDetail = true
                        }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let request = selectedRequest {
                NavigationView {
                    MaintenancePersonnelServiceRequestDetailView(request: request, dataStore: dataStore)
                        .navigationTitle("Service Request Details")
                        .navigationBarItems(trailing: Button("Done") {
                            showingDetail = false
                        })
                }
            }
        }
    }
}

struct StatusFilterButton: View {
    let status: ServiceRequestStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(status.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ServiceRequestRow: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.vehicleName)
                    .font(.headline)
                Spacer()
                StatusBadge(status: request.status)
            }
            
            Text(request.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(request.serviceType.rawValue, systemImage: "wrench")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(request.priority.rawValue, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(priorityColor)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var priorityColor: Color {
        switch request.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

struct StatusBadge: View {
    let status: ServiceRequestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .assigned: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

#Preview {
    MaintenancePersonnelDashboardView()
} 
