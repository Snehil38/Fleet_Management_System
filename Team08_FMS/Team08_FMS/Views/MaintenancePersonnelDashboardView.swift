import SwiftUI

struct MaintenancePersonnelDashboardView: View {
    @StateObject private var dataStore = MaintenancePersonnelDataStore()
    @State private var selectedTab = 0
    @State private var selectedStatus: ServiceRequestStatus = .pending
    @State private var showingNewRequest = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                serviceRequestsTab
                    .tabItem {
                        Label("Service Requests", systemImage: "wrench.fill")
                    }
                    .tag(0)
                
                upcomingServicesTab
                    .tabItem {
                        Label("Inspection", systemImage: "checklist")
                    }
                    .tag(1)
            }
            .sheet(isPresented: $showingNewRequest) {
                newRequestSheet
            }
            .sheet(isPresented: $showingProfile) {
                profileSheet
            }
            .onChange(of: dataStore.serviceRequests) { _ in
                checkForCompletedRequests()
            }
        }
    }
    
    private var serviceRequestsTab: some View {
        NavigationView {
            VStack(spacing: 0) {
                statusFilter
                serviceRequestsList
            }
            .navigationTitle("Service Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private var statusFilter: some View {
        Picker("Status", selection: $selectedStatus) {
            Text("Pending (\(pendingCount))").tag(ServiceRequestStatus.pending)
            Text("In Progress (\(inProgressCount))").tag(ServiceRequestStatus.inProgress)
            Text("Completed (\(completedCount))").tag(ServiceRequestStatus.completed)
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var serviceRequestsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredRequests) { request in
                    NavigationLink(destination: MaintenancePersonnelServiceRequestDetailView(request: request, dataStore: dataStore)) {
                        ServiceRequestCard(request: request)
                    }
                }
            }
            .padding()
        }
    }
    
    private var toolbarButtons: some View {
        Button(action: { showingProfile = true }) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
        }
    }
    
    private var upcomingServicesTab: some View {
        MaintenancePersonnelUpcomingServicesView(dataStore: dataStore)
            .navigationTitle("Inspection")
            .navigationBarTitleDisplayMode(.inline)
    }
    
    private var newRequestSheet: some View {
        NavigationView {
            MaintenancePersonnelNewServiceRequestView(dataStore: dataStore)
                .navigationTitle("New Service Request")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingNewRequest = false
                })
        }
    }
    
    private var profileSheet: some View {
        NavigationView {
            MaintenancePersonnelProfileView()
                .navigationTitle("Profile")
                .navigationBarItems(trailing: Button("Done") {
                    showingProfile = false
                })
        }
    }
    
    private var filteredRequests: [MaintenanceServiceRequest] {
        dataStore.serviceRequests.filter { $0.status == selectedStatus }
    }
    
    private func checkForCompletedRequests() {
        if let completedRequest = dataStore.serviceRequests.first(where: { 
            $0.status == .completed && 
            $0.completionDate?.timeIntervalSinceNow ?? 0 > -1 
        }) {
            selectedStatus = .completed
        }
    }
    
    private var pendingCount: Int {
        dataStore.serviceRequests.filter { $0.status == .pending }.count
    }
    
    private var inProgressCount: Int {
        dataStore.serviceRequests.filter { $0.status == .inProgress }.count
    }
    
    private var completedCount: Int {
        dataStore.serviceRequests.filter { $0.status == .completed }.count
    }
}

struct ServiceRequestCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.vehicleName)
                        .font(.system(.headline, design: .default))
                    
                    Text(request.serviceType.rawValue)
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: request.status)
            }
            
            Divider()
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                Text(request.description)
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if request.status == .inProgress {
                    Label("\(request.expenses.count) Expenses", systemImage: "dollarsign.circle.fill")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.green)
                }
            }
            
            if request.status == .inProgress && !request.expenses.isEmpty {
                Divider()
                
                // Recent Expenses Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Expenses")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(request.expenses.prefix(2)) { expense in
                        HStack {
                            Text(expense.description)
                                .font(.caption)
                            Spacer()
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if request.expenses.count > 2 {
                        Text("+ \(request.expenses.count - 2) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
