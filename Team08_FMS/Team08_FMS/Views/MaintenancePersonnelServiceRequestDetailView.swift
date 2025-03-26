import SwiftUI

struct MaintenancePersonnelServiceRequestDetailView: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingContactManager = false
    @State private var messageText = ""
    @State private var isSendingMessage = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Vehicle Info Card
                MaintenanceVehicleRequestInfoCard(request: request)
                
                // Service Details Card
                MaintenanceServiceDetailsCard(request: request)
                
                // Safety Checks Card
                if !request.safetyChecks.isEmpty {
                    MaintenanceSafetyChecksCard(checks: request.safetyChecks)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        dataStore.updateServiceRequestStatus(request, newStatus: .inProgress)
                        alertMessage = "Service request marked as in progress"
                        showingAlert = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Maintenance")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingContactManager = true
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Contact Fleet Manager")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .alert("Success", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
//        .sheet(isPresented: $showingContactManager) {
//            NavigationView {
//                ContactFleetManagerView()
//                    .navigationTitle("Contact Fleet Manager")
//                    .navigationBarItems(trailing: Button("Cancel") {
//                        showingContactManager = false
//                    })
//            }
//        }
    }
}

struct MaintenanceVehicleRequestInfoCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Information")
                .font(.headline)
            
            Divider()
            
            InfoRow(title: "Vehicle", value: request.vehicleName, icon: "car.fill")
            InfoRow(title: "Service Type", value: request.serviceType.rawValue, icon: "wrench.fill")
            InfoRow(title: "Priority", value: request.priority.rawValue, icon: "exclamationmark.triangle.fill")
            InfoRow(title: "Due Date", value: request.dueDate.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct MaintenanceServiceDetailsCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Details")
                .font(.headline)
            
            Divider()
            
            Text(request.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let issueType = request.issueType {
                Text("Issue Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                Text(issueType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !request.notes.isEmpty {
                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                Text(request.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct MaintenanceSafetyChecksCard: View {
    let checks: [SafetyCheck]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety Checks")
                .font(.headline)
            
            Divider()
            
            ForEach(checks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(check.isChecked ? .green : .gray)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.item)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if !check.notes.isEmpty {
                            Text(check.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if check.id != checks.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    MaintenancePersonnelServiceRequestDetailView(
        request: MaintenanceServiceRequest(
            id: UUID(),
            vehicleId: UUID(),
            vehicleName: "Test Vehicle",
            serviceType: .routine,
            description: "Test Description",
            priority: .medium,
            date: Date(),
            dueDate: Date().addingTimeInterval(86400),
            status: .pending,
            notes: "Test Notes",
            issueType: nil,
            safetyChecks: []
        ),
        dataStore: MaintenancePersonnelDataStore()
    )
} 
