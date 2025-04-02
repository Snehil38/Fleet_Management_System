import SwiftUI
import Foundation

// For files within the same Xcode project but not in a separate module,
// we don't need to import them as modules.
// Make sure these files are included in the target's Compile Sources build phase.

struct DriverProfileView: View {
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var driver: Driver?
    @State private var isEditMode = false
    @State private var updatedName = ""
    @State private var updatedEmail = ""
    @State private var updatedPhone = ""
    @State private var updatedLicense = ""
    @State private var updatedExperience = ""
    @State private var updatedSalary = ""
    @State private var updatedStatus: Status
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutAlert = false
    @State private var showingLanguageSettings = false

    init(driver: Driver = Driver(
        userID: UUID(),
        id: UUID(), 
        name: "John Doe", 
        profileImage: nil,
        email: "john.doe@example.com", 
        phoneNumber: 1234567890,
        driverLicenseNumber: "DL12345",
        driverLicenseExpiry: Date().addingTimeInterval(60*60*24*365),
        assignedVehicleID: nil,
        address: "123 Main St",
        salary: 55000, 
        yearsOfExperience: 5,
        createdAt: Date(),
        updatedAt: Date(),
        isDeleted: false,
        status: .available
    )) {
        _driver = State(initialValue: driver)
        _updatedName = State(initialValue: driver.name)
        _updatedEmail = State(initialValue: driver.email)
        _updatedPhone = State(initialValue: "\(driver.phoneNumber)")
        _updatedLicense = State(initialValue: driver.driverLicenseNumber)
        _updatedExperience = State(initialValue: "\(driver.yearsOfExperience)")
        _updatedSalary = State(initialValue: "\(driver.salary)")
        _updatedStatus = State(initialValue: driver.status)
    }

    var body: some View {
        NavigationView {
            Group {
                if let driver = driver {
                    driverContentView(driver: driver)
                } else {
                    ProgressView("Loading...".localized)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Driver Profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back".localized) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Confirmation".localized),
                    message: Text(alertMessage),
                    primaryButton: .destructive(Text("Delete".localized)) {
                        // Delete action would be implemented in a real app
                        dismiss()
                    },
                    secondaryButton: .cancel(Text("Cancel".localized))
                )
            }
            .task {
                if let userID = await supabaseDataController.getUserID() {
                    do {
                        if let fetchedDriver = try await supabaseDataController.fetchDriverByUserID(userID: userID) {
                            self.driver = fetchedDriver
                        }
                    } catch {
                        print("Error fetching driver: \(error)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                // Fix the objectWillChange issue
                // Instead of sending objectWillChange directly, 
                // we'll just reload the driver data to refresh the view
                func refreshDriver() async {
                    do {
                        guard let userID = await supabaseDataController.getUserID() else { return }
                        if let fetchedDriver = try await supabaseDataController.fetchDriverByUserID(userID: userID) {
                            self.driver = fetchedDriver
                        }
                    } catch {
                        print("Error refreshing driver after language change: \(error)")
                    }
                }
                Task {
                    await refreshDriver()
                }
            }
            .sheet(isPresented: $showingLanguageSettings) {
                LanguageSettingsView()
            }
        }
    }
    
    // Break down the view into smaller pieces
    @ViewBuilder
    private func driverContentView(driver: Driver) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Profile Header
                profileHeaderSection(driver: driver)
                
                // Personal Information
                personalInfoSection(driver: driver)
                
                // Employment Information
                employmentInfoSection(driver: driver)
                
                // Performance Section
                performanceSection()
                
                // App Settings
                appSettingsSection()
                
                // Delete Button (if not in edit mode)
                if !isEditMode {
                    deleteButtonSection()
                }
            }
            .padding()
        }
    }
    
    // Profile Header Section
    @ViewBuilder
    private func profileHeaderSection(driver: Driver) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "person.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .padding()
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                if isEditMode {
                    TextField("Name".localized, text: $updatedName)
                        .font(.title)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                } else {
                    Text(driver.name)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Status:".localized)
                    DriverStatusBadge(status: driver.status)
                }
            }
            
            Spacer()
            
            Button(action: {
                if isEditMode {
                    saveChanges()
                }
                isEditMode.toggle()
            }) {
                Text(isEditMode ? "Save".localized : "Edit".localized)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Personal Information Section
    @ViewBuilder
    private func personalInfoSection(driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Personal Information".localized)
                .font(.headline)
                .padding(.bottom, 5)
            
            DriverInfoRow(title: "Email".localized, value: driver.email, editableValue: $updatedEmail, isEditMode: isEditMode)
            DriverInfoRow(title: "Phone".localized, value: "\(driver.phoneNumber)", editableValue: $updatedPhone, isEditMode: isEditMode)
            DriverInfoRow(title: "Driver License".localized, value: driver.driverLicenseNumber, editableValue: $updatedLicense, isEditMode: isEditMode)
            
            if isEditMode {
                VStack(alignment: .leading) {
                    Text("Status".localized)
                        .fontWeight(.semibold)
                    
                    Picker("Status".localized, selection: $updatedStatus) {
                        // Fix for Status.allCases issue
                        // Instead of using allCases, manually enumerate the status values
                        Text("Available".localized).tag(Status.available)
                        Text("Busy".localized).tag(Status.busy)
                        Text("Off Duty".localized).tag(Status.offDuty)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Employment Information Section
    @ViewBuilder
    private func employmentInfoSection(driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Employment Information".localized)
                .font(.headline)
                .padding(.bottom, 5)
            
            DriverInfoRow(title: "Years of Experience".localized, value: "\(driver.yearsOfExperience)", editableValue: $updatedExperience, isEditMode: isEditMode)
            DriverInfoRow(title: "Salary".localized, value: "$\(String(format: "%.2f", driver.salary))", editableValue: $updatedSalary, isEditMode: isEditMode)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Performance Section (placeholder)
    @ViewBuilder
    private func performanceSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Performance Metrics".localized)
                .font(.headline)
                .padding(.bottom, 5)
            
            Text("Performance data would be displayed here.".localized)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // App Settings Section
    @ViewBuilder
    private func appSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("App Settings".localized)
                .font(.headline)
                .padding(.bottom, 5)
            
            Button(action: {
                showingLanguageSettings = true
            }) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text("Language".localized)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(languageManager.currentLanguage.uppercased())
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // Delete Button Section
    @ViewBuilder
    private func deleteButtonSection() -> some View {
        Button(action: {
            // Delete action would be implemented in a real app
            showAlert = true
            alertMessage = "Are you sure you want to delete this driver?".localized
        }) {
            Text("Delete Driver".localized)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(10)
        }
    }
    
    private func saveChanges() {
        // Validate input
        guard let phoneNumber = Int(updatedPhone) else {
            showAlert = true
            alertMessage = "Phone number must be numeric.".localized
            return
        }
        
        guard let experience = Int(updatedExperience) else {
            showAlert = true
            alertMessage = "Experience must be a number.".localized
            return
        }
        
        guard let salary = Double(updatedSalary) else {
            showAlert = true
            alertMessage = "Salary must be a number.".localized
            return
        }
        
        // Update driver object
        driver?.name = updatedName
        driver?.email = updatedEmail
        driver?.phoneNumber = phoneNumber
        driver?.driverLicenseNumber = updatedLicense
        driver?.yearsOfExperience = experience
        driver?.salary = salary
        driver?.status = updatedStatus
        
        // Show success message
        showAlert = true
        alertMessage = "Driver information updated successfully.".localized
    }
}

struct DriverInfoRow: View {
    var title: String
    var value: String
    @Binding var editableValue: String
    var isEditMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .fontWeight(.semibold)
            
            if isEditMode {
                TextField(title, text: $editableValue)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(5)
            } else {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DriverStatusBadge: View {
    var status: Status
    
    var body: some View {
        Text(status.rawValue.capitalized.localized)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color)
            .cornerRadius(10)
    }
}

struct LicenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let name: String
    let licenseNumber: String
    let expiryDate: String

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    licenseCard
                }
                .padding()
            }
            .navigationTitle("Driver License".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var licenseCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DRIVER LICENSE".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.7))
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 100)
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                        .frame(width: 50)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("№")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(licenseNumber)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Text("EXP".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(expiryDate)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Text("NAME".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(name)
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
