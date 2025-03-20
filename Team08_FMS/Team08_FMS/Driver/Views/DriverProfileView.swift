import SwiftUI

struct DriverProfileView: View {
    @StateObject private var auth = SupabaseDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingStatusChangeAlert = false
    @State private var pendingAvailabilityChange = false
    
    // Sample data for fields not available from auth
    private let driverName = "John Anderson"
    private let driverTitle = "Professional Driver"
    private let driverEmail = "john.anderson@company.com"
    private let phoneNumber = "+1 (555) 123-4567"
    private let licenseNumber = "DL12345678"
    private let licenseExpiry = "07/11/2025"
    private let experience = "5 Years"
    private let vehicleType = "Heavy Truck"
    private let specializedTerrain = "Mountain, Highway"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header with photo, name and availability toggle
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text(driverName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(driverTitle)
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text("Availability Status")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !availabilityManager.isAvailable {
                                Text("Unavailable")
                                    .foregroundColor(.red)
                                    .padding(.trailing, 8)
                            } else {
                                Text("Available")
                                    .foregroundColor(.green)
                                    .padding(.trailing, 8)
                            }
                            
                            Toggle("", isOn: Binding(
                                get: { availabilityManager.isAvailable },
                                set: { newValue in
                                    // Only allow showing the alert if they're trying to change status
                                    if newValue != availabilityManager.isAvailable {
                                        pendingAvailabilityChange = newValue
                                        showingStatusChangeAlert = true
                                    }
                                }
                            ))
                            .tint(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // CONTACT INFORMATION
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CONTACT INFORMATION")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Phone")
                                    .font(.headline)
                                Spacer()
                                Text(phoneNumber)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Email")
                                    .font(.headline)
                                Spacer()
                                Text(driverEmail)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    
                    // LICENSE INFORMATION
                    VStack(alignment: .leading, spacing: 0) {
                        Text("LICENSE INFORMATION")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 0) {
                            NavigationLink {
                                LicenseDetailView(
                                    name: driverName,
                                    licenseNumber: licenseNumber,
                                    expiryDate: licenseExpiry
                                )
                            } label: {
                                HStack {
                                    Text("Driver License")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("License Number")
                                    .font(.headline)
                                Spacer()
                                Text(licenseNumber)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Expiry Date")
                                    .font(.headline)
                                Spacer()
                                Text(licenseExpiry)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    
                    // EXPERIENCE & EXPERTISE
                    VStack(alignment: .leading, spacing: 0) {
                        Text("EXPERIENCE & EXPERTISE")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Experience")
                                    .font(.headline)
                                Spacer()
                                Text(experience)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Vehicle Type")
                                    .font(.headline)
                                Spacer()
                                Text(vehicleType)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            HStack {
                                Text("Specialized Terrain")
                                    .font(.headline)
                                Spacer()
                                Text(specializedTerrain)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    
                    // Logout Button
                    Button {
                        auth.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Logout")
                                .font(.headline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingStatusChangeAlert) {
                if pendingAvailabilityChange {
                    // Going from unavailable to available - show the same style alert as when already unavailable
                    return Alert(
                        title: Text("Status Change"),
                        message: Text("Your status will automatically change back to available tomorrow."),
                        dismissButton: .default(Text("OK")) {
                            // Don't change status - keep as unavailable
                        }
                    )
                } else {
                    // Going from available to unavailable
                    if availabilityManager.isAvailable {
                        return Alert(
                            title: Text("Status Change"),
                            message: Text("Are you sure you want to change your status to unavailable? You won't be able to change it back until tomorrow."),
                            primaryButton: .cancel(Text("Cancel")),
                            secondaryButton: .default(Text("Continue")) {
                                availabilityManager.updateAvailability(newStatus: false)
                            }
                        )
                    } else {
                        // Already unavailable, showing confirmation
                        return Alert(
                            title: Text("Status Change"),
                            message: Text("Your status will automatically change back to available tomorrow."),
                            dismissButton: .default(Text("OK")) {
                                // Do nothing, already unavailable
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
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
                    // License card
                    VStack(spacing: 0) {
                        // License header
                        HStack {
                            Text("DRIVER LICENSE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.7))
                        
                        // License content
                        HStack(alignment: .top, spacing: 12) {
                            // Photo
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
                            
                            // License details
                            VStack(alignment: .leading, spacing: 6) {
                                Group {
                                    HStack(spacing: 4) {
                                        Text("№")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(licenseNumber)
                                            .font(.caption)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text("EXP")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(expiryDate)
                                            .font(.caption)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text("NAME")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(name)
                                            .font(.caption)
                                    }
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
                .padding()
            }
            .navigationTitle("Driver License")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DriverProfileView()
    }
} 