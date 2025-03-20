import SwiftUI
import Supabase

struct AddDriverView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var supabase = SupabaseDataController.shared
    @StateObject private var crewDataController = CrewDataController.shared
    
    // Driver information
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var licenseNumber = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var address = ""
    @State private var licenseExpiration = Date()
    @State private var salary = ""
    
    let licenseTypes = ["Class A CDL", "Class B CDL", "Class C CDL", "Non-CDL"]
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !experience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !salary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(salary) ?? 0 > 0 &&
        Int(experience) != nil &&
        !licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Full Name", text: $name)
                    TextField("Avatar (optional)", text: $avatar)
                        .onChange(of: name) { _, _ in
                            if avatar.isEmpty {
                                let words = name.components(separatedBy: " ")
                                avatar = words.compactMap { $0.first }.map(String.init).joined()
                            }
                        }
                }
                
                // Contact Information
                Section("Contact Information") {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Address", text: $address)
                }
                
                // Professional Details
                Section("Professional Details") {
                    TextField("Experience (years)", text: $experience)
                        .keyboardType(.numberPad)
                    
                    TextField("Driver License Number", text: $licenseNumber)
                    
                    DatePicker("License Expiration", selection: $licenseExpiration, displayedComponents: .date)
                }
                
                // Compensation
                Section("Compensation") {
                    TextField("Monthly Salary", text: $salary)
                        .keyboardType(.decimalPad)
                        .onChange(of: salary) { _, newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                salary = filtered
                            }
                        }
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDriver()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func saveDriver() {
        Task {
            guard let salaryDouble = Double(salary),
                  let experienceInt = Int(experience),
                let phoneNumberInt = Int(phoneNumber) else {
                print("Invalid salary or experience format.")
                return
            }
            
            // Create a new Driver instance. Make sure your Driver model conforms to Codable.
            var newDriver = Driver(
                userID: UUID(),
                name: name,
                profileImage: avatar.isEmpty ? nil : avatar,
                email: email,
                phoneNumber: phoneNumberInt,
                driverLicenseNumber: licenseNumber,
                driverLicenseExpiry: licenseExpiration,
                assignedVehicleID: nil,
                address: address,
                salary: salaryDouble,
                yearsOfExperience: experienceInt,
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                status: .available
            )
            
            Task {
                do {
                    guard let signUpID = await supabase.signUp(name: newDriver.name, email: newDriver.email, phoneNo: newDriver.phoneNumber, role: "maintenance_personnel") else { return }
                    newDriver.userID = signUpID
                    // Call the SupabaseDataController function to insert the driver
                    try await supabase.insertDriver(driver: newDriver, password: AppDataController.shared.randomPasswordGenerator(length: 6))
                    await MainActor.run {
                        crewDataController.update()
                        presentationMode.wrappedValue.dismiss()
                    }
                } catch {
                    print("Error saving driver: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    AddDriverView()
        .environmentObject(SupabaseDataController.shared)
}
