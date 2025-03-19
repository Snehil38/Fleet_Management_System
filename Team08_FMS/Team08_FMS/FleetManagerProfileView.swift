import SwiftUI

struct FleetManagerProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appDataController: AppDataController
    
    var body: some View {
        Form {
            Section("Personal Information") {
                LabeledContent("Name", value: "John Smith")
                LabeledContent("Role", value: "Fleet Manager")
                LabeledContent("ID", value: "FM001")
            }
            
            Section("Contact Information") {
                LabeledContent("Email", value: "john.smith@company.com")
                LabeledContent("Phone", value: "+1 (555) 123-4567")
            }
            
            Section("Work Information") {
                LabeledContent("Department", value: "Fleet Operations")
                LabeledContent("Location", value: "Main Office")
                LabeledContent("Working Hours", value: "9:00 AM - 5:00 PM")
            }
            
            Section {
                Button("Log Out", role: .destructive) {
                    appDataController.logout()
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

//#Preview {
//    NavigationView {
//        FleetManagerProfileView()
//            .environmentObject(AppDataController())
//    }
//} 
