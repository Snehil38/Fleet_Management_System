import SwiftUI

struct InspectionItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    var isChecked: Bool = false
    var hasIssue: Bool = false
    var notes: String = ""
}

struct VehicleInspectionView: View {
    @Environment(\.presentationMode) var presentationMode
    let isPreTrip: Bool
    var onComplete: (Bool) -> Void
    
    @State private var inspectionItems: [InspectionItem] = []
    @State private var showingConfirmation = false
    @State private var currentSection = 0
    
    let sections = ["Exterior", "Interior", "Mechanical", "Safety"]
    
    init(isPreTrip: Bool, onComplete: @escaping (Bool) -> Void) {
        self.isPreTrip = isPreTrip
        self.onComplete = onComplete
        
        // Initialize with default items
        _inspectionItems = State(initialValue: [
            // Exterior
            InspectionItem(title: "Lights", description: "Check all exterior lights"),
            InspectionItem(title: "Tires", description: "Check tire pressure and wear"),
            InspectionItem(title: "Body Damage", description: "Inspect for any damage"),
            
            // Interior
            InspectionItem(title: "Dashboard", description: "Check all gauges and warning lights"),
            InspectionItem(title: "Seats & Belts", description: "Inspect seats and seatbelts"),
            InspectionItem(title: "Controls", description: "Test all controls and switches"),
            
            // Mechanical
            InspectionItem(title: "Engine", description: "Check engine operation"),
            InspectionItem(title: "Brakes", description: "Test brake system"),
            InspectionItem(title: "Fluid Levels", description: "Check all fluid levels"),
            
            // Safety
            InspectionItem(title: "Emergency Kit", description: "Verify emergency equipment"),
            InspectionItem(title: "Fire Extinguisher", description: "Check expiration and pressure"),
            InspectionItem(title: "First Aid Kit", description: "Verify contents and expiration")
        ])
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentSection), total: Double(sections.count))
                    .padding()
                
                // Section title
                Text(sections[currentSection])
                    .font(.title)
                    .padding(.bottom)
                
                // Inspection items
                ScrollView {
                    VStack(spacing: 16) {
                        let sectionStart = currentSection * 3
                        let sectionItems = Array(inspectionItems[sectionStart..<sectionStart+3])
                        
                        ForEach(sectionItems) { item in
                            InspectionItemView(item: binding(for: item))
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentSection > 0 {
                        Button(action: { currentSection -= 1 }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    
                    if currentSection < sections.count - 1 {
                        Button(action: { currentSection += 1 }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: { showingConfirmation = true }) {
                            Text("Complete Inspection")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(isPreTrip ? "Pre-Trip Inspection" : "Post-Trip Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Confirm Inspection"),
                    message: Text("Are you sure you want to complete the inspection?"),
                    primaryButton: .default(Text("Complete")) {
                        let hasIssues = inspectionItems.contains { $0.hasIssue }
                        onComplete(!hasIssues)
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func binding(for item: InspectionItem) -> Binding<InspectionItem> {
        guard let index = inspectionItems.firstIndex(where: { $0.id == item.id }) else {
            fatalError("Item not found")
        }
        return $inspectionItems[index]
    }
}

struct InspectionItemView: View {
    @Binding var item: InspectionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { item.isChecked.toggle() }) {
                    ZStack {
                        Circle()
                            .stroke(item.isChecked ? Color.green : Color.gray, lineWidth: 2)
                            .frame(width: 30, height: 30)
                        
                        if item.isChecked {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            if item.isChecked {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { item.hasIssue.toggle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: item.hasIssue ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .foregroundColor(item.hasIssue ? .red : .gray)
                            
                            Text("Issue Found")
                                .foregroundColor(item.hasIssue ? .red : .gray)
                            
                            Spacer()
                            
                            if item.hasIssue {
                                Text("Tap to Clear")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(10)
                        .background(item.hasIssue ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if item.hasIssue {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Issue Details")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            TextEditor(text: $item.notes)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            HStack {
                                Image(systemName: "camera")
                                Text("Add Photo")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct VehicleInspectionView_Previews: PreviewProvider {
    static var previews: some View {
        VehicleInspectionView(isPreTrip: true) { _ in }
    }
} 