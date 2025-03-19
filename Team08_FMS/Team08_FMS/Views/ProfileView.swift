import SwiftUI

struct ProfileView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var showingLicensePhoto = false
    @State private var showingUnavailableAlert = false
    @State private var showingCannotChangeAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                            .padding(.top)
                        
                        Text("John Anderson")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Professional Driver")
                            .foregroundColor(.gray)
                        
                        Toggle("Available", isOn: Binding(
                            get: { availabilityManager.isAvailable },
                            set: { newValue in
                                if newValue && !availabilityManager.isAvailable {
                                    // Trying to change from unavailable to available
                                    if !availabilityManager.canChangeToAvailable() {
                                        showingCannotChangeAlert = true
                                    }
                                } else if !newValue && availabilityManager.isAvailable {
                                    // Trying to change from available to unavailable
                                    showingUnavailableAlert = true
                                }
                            }
                        ))
                        .padding(.vertical)
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section(header: Text("Contact Information")) {
                    LabeledContent("Phone", value: "+1 (555) 123-4567")
                    LabeledContent("Email", value: "john.anderson@company.com")
                }
                
                Section(header: Text("License Information")) {
                    Button(action: {
                        showingLicensePhoto = true
                    }) {
                        HStack {
                            Text("Driver License")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    LabeledContent("License Number", value: "DL12345678")
                    LabeledContent("Expiry Date", value: "07/11/2025")
                }
                
                Section(header: Text("Experience & Expertise")) {
                    LabeledContent("Experience", value: "5 Years")
                    LabeledContent("Vehicle Type", value: "Heavy Truck")
                    LabeledContent("Specialized Terrain", value: "Mountain, Highway")
                }
                
                Section {
                    Button(action: {
                        // Implement logout
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Set Unavailable", isPresented: $showingUnavailableAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    availabilityManager.setUnavailable()
                }
            } message: {
                Text("Once set to unavailable, you cannot change back to available until the next day. Do you want to continue?")
            }
            .alert("Cannot Change Status", isPresented: $showingCannotChangeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can only change your status back to available on the next day.")
            }
            .sheet(isPresented: $showingLicensePhoto) {
                NavigationView {
                    VStack {
                        Image(systemName: "person.text.rectangle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("Driver License Photo")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .navigationBarItems(trailing: Button("Done") {
                        showingLicensePhoto = false
                    })
                }
            }
        }
    }
}

#Preview {
    ProfileView()
} 
