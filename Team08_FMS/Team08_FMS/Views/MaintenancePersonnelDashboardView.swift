import SwiftUI

struct MaintenancePersonnelDashboardView: View {
    @StateObject private var dataStore = MaintenancePersonnelDataStore()
    @State private var selectedTab = 0
    @State private var showingNewRequest = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                NavigationView {
                    ServiceRequestListView(dataStore: dataStore)
                        .navigationTitle("Dashboard")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingProfile = true }) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Dashboard", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(0)
                
                // Upcoming Services Tab
                NavigationView {
                    MaintenancePersonnelUpcomingServicesView(dataStore: dataStore)
                        .navigationTitle("Upcoming Services")
                        .toolbar {
                            ToolbarItemGroup(placement: .navigationBarTrailing) {
                                Button(action: { showingNewRequest = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                
                                Button(action: { showingProfile = true }) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(1)
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
            .sheet(isPresented: $showingProfile) {
                MaintenancePersonnelProfileView()
            }
        }
    }
}

struct ServiceRequestListView: View {
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @State private var searchText = ""
    @State private var selectedStatus: ServiceRequestStatus?
    @State private var selectedRequest: MaintenanceServiceRequest?
    @State private var showingDetail = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                        ForEach([ServiceRequestStatus.pending, .inProgress, .completed], id: \.self) { status in
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
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                List(filteredRequests) { request in
                    ServiceRequestRow(request: request, dataStore: dataStore)
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
                        .navigationTitle("Request Details")
                        .navigationBarItems(trailing: Button("Done") {
                            showingDetail = false
                        })
                }
            }
        }
        .alert("Status Updated", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

struct ServiceRequestRow: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    
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
            
            // Action Button based on status
            if request.status == .pending {
                Button(action: {
                    dataStore.updateServiceRequestStatus(request, newStatus: .inProgress)
                }) {
                    Text("Start Maintenance")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else if request.status == .inProgress {
                Button(action: {
                    dataStore.updateServiceRequestStatus(request, newStatus: .completed)
                }) {
                    Text("Complete Maintenance")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
