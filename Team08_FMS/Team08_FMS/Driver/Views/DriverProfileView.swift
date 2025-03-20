import SwiftUI

struct DriverProfileView: View {
    @StateObject private var auth = SupabaseDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    
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
        ScrollView {
            VStack(spacing: 0) {
                // Profile header section
                VStack(spacing: 16) {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 20) {
                        // Avatar and name
                        VStack(spacing: 8) {
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
                        }
                        
                        // Available toggle
                        HStack {
                            Text("Available for Trips")
                                .font(.headline)
                            
                            Spacer()
                            
                            Toggle("", isOn: $availabilityManager.isAvailable)
                                .tint(.green)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
                
                // Contact Information
                SectionHeader(title: "CONTACT INFORMATION")
                
                VStack(spacing: 0) {
                    ProfileRow(title: "Phone", value: phoneNumber)
                    Divider()
                    ProfileRow(title: "Email", value: driverEmail)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.bottom, 20)
                
                // License Information
                SectionHeader(title: "LICENSE INFORMATION")
                
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
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    
                    Divider()
                    ProfileRow(title: "License Number", value: licenseNumber)
                    Divider()
                    ProfileRow(title: "Expiry Date", value: licenseExpiry)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.bottom, 20)
                
                // Experience & Expertise
                SectionHeader(title: "EXPERIENCE & EXPERTISE")
                
                VStack(spacing: 0) {
                    ProfileRow(title: "Experience", value: experience)
                    Divider()
                    ProfileRow(title: "Vehicle Type", value: vehicleType)
                    Divider()
                    ProfileRow(title: "Specialized Terrain", value: specializedTerrain)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.bottom, 20)
                
                // Logout Button
                Button(action: {
                    auth.signOut()
                }) {
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
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