import SwiftUI

struct MaintenancePersonnelServiceRequestDetailView: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingExpenseSheet = false
    @State private var showingCompletionAlert = false
    @State private var expenseDescription = ""
    @State private var expenseAmount = ""
    @State private var selectedExpenseCategory: ExpenseCategory = .parts
    @State private var showingSafetyChecks = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Vehicle Info Card
                MaintenanceVehicleRequestInfoCard(request: request)
                    .padding(.horizontal)
                
                // Service Details Card
                MaintenanceServiceDetailsCard(request: request)
                    .padding(.horizontal)
                
                // Safety Checks Card
                if !request.safetyChecks.isEmpty {
                    MaintenanceSafetyChecksCard(checks: request.safetyChecks)
                        .padding(.horizontal)
                }
                
                // Expenses Card
                if request.status != .pending {
                    ExpensesCard(request: request)
                        .padding(.horizontal)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if request.status == .pending {
                        Button(action: {
                            startMaintenance()
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
                    } else if request.status == .inProgress {
                        Button(action: {
                            showingExpenseSheet = true
                        }) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                Text("Add Expense")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            if request.expenses.isEmpty {
                                alertMessage = "You must add at least one expense before completing the maintenance"
                                showingAlert = true
                            } else {
                                showingCompletionAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Completed")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(request.expenses.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(request.expenses.isEmpty)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Service Request Details")
        .navigationBarTitleDisplayMode(.large)
        .alert("Success", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingExpenseSheet) {
            NavigationView {
                AddExpenseView(
                    request: request,
                    dataStore: dataStore,
                    description: $expenseDescription,
                    amount: $expenseAmount,
                    category: $selectedExpenseCategory,
                    isPresented: $showingExpenseSheet
                )
            }
        }
        .alert("Complete Service Request", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Complete") {
                completeServiceRequest()
            }
        } message: {
            Text("Are you sure you want to mark this service request as completed?")
        }
    }
    
    private func startMaintenance() {
        dataStore.updateServiceRequestStatus(request, newStatus: .inProgress)
        alertMessage = "Maintenance started successfully"
        showingAlert = true
        // Dismiss the view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func completeServiceRequest() {
        dataStore.updateServiceRequestStatus(request, newStatus: .completed)
        dataStore.addToServiceHistory(request)
        alertMessage = "Service request marked as completed"
        showingAlert = true
        // Dismiss the view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

struct ExpensesCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses")
                    .font(.headline)
                Spacer()
                Text("Total: $\(request.totalCost, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Divider()
            
            if request.expenses.isEmpty {
                Text("No expenses added yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(request.expenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.subheadline)
                Text(expense.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Text(expense.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddExpenseView: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @Binding var description: String
    @Binding var amount: String
    @Binding var category: ExpenseCategory
    @Binding var isPresented: Bool
    
    var body: some View {
        Form {
            Section("Expense Details") {
                TextField("Description", text: $description)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }
        }
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    addExpense()
                }
                .disabled(description.isEmpty || amount.isEmpty)
            }
        }
    }
    
    private func addExpense() {
        guard let amountValue = Double(amount) else { return }
        
        let expense = Expense(
            description: description,
            amount: amountValue,
            date: Date(),
            category: category
        )
        
        dataStore.addExpense(to: request, expense: expense)
        description = ""
        amount = ""
        category = .parts
        isPresented = false
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

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
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
    NavigationView {
        MaintenancePersonnelServiceRequestDetailView(
            request: MaintenanceServiceRequest(
                vehicleId: UUID(),
                vehicleName: "Test Vehicle",
                serviceType: .routine,
                description: "Test Description",
                priority: .medium,
                date: Date(),
                dueDate: Date().addingTimeInterval(86400),
                status: .pending,
                notes: "Test Notes",
                issueType: nil
            ),
            dataStore: MaintenancePersonnelDataStore()
        )
    }
} 
