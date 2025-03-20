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
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Progress section
                    VStack(spacing: 8) {
                        // Progress bar
                        ProgressView(value: Double(currentSection + 1), total: Double(sections.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .padding(.horizontal)
                        
                        // Section text
                        HStack {
                            Text("Section \(currentSection + 1) of \(sections.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(sections[currentSection])")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    
                    // Inspection items
                    ScrollView {
                        VStack(spacing: 16) {
                            let sectionStart = currentSection * 3
                            let sectionItems = Array(inspectionItems[sectionStart..<sectionStart+3])
                            
                            ForEach(sectionItems) { item in
                                InspectionItemView(item: binding(for: item))
                            }
                            
                            Spacer().frame(height: 60) // Space for the buttons
                        }
                        .padding()
                    }
                }
                
                // Bottom navigation buttons
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if currentSection > 0 {
                            Button(action: { currentSection -= 1 }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                        }
                        
                        if currentSection < sections.count - 1 {
                            Button(action: { currentSection += 1 }) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                        } else {
                            Button(action: { showingConfirmation = true }) {
                                Text("Complete Inspection")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(allItemsChecked ? Color.green : Color(.systemGray4))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            .disabled(!allItemsChecked)
                        }
                    }
                    .padding()
                    .background(
                        Color(.systemBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -3)
                    )
                }
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
                    message: Text(allItemsChecked ? 
                        "Are you sure you want to complete the inspection?" : 
                        "All items must be checked before completing the inspection."),
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
    
    // Check if all items have been checked
    private var allItemsChecked: Bool {
        !inspectionItems.contains { !$0.isChecked }
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
        VStack(alignment: .leading, spacing: 0) {
            // Main item row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { item.isChecked.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(item.isChecked ? Color.green : Color(.systemBackground))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(item.isChecked ? Color.green : Color(.systemGray4), lineWidth: 2)
                            )
                        
                        if item.isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10, corners: item.isChecked && item.hasIssue ? [.topLeft, .topRight] : .allCorners)
            
            // Issue section (only shown when checked)
            if item.isChecked {
                Divider()
                    .padding(.horizontal)
                
                Button(action: { item.hasIssue.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.hasIssue ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .foregroundColor(item.hasIssue ? .red : .gray)
                        
                        Text("Report Issue")
                            .font(.subheadline)
                            .foregroundColor(item.hasIssue ? .red : .gray)
                        
                        Spacer()
                        
                        if item.hasIssue {
                            Text("Tap to Clear")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(item.hasIssue ? .red : .secondary)
                            .opacity(item.hasIssue ? 1 : 0)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                .cornerRadius(10, corners: item.hasIssue ? [.bottomLeft, .bottomRight] : .allCorners)
            }
            
            // Issue details (only shown when issue is reported)
            if item.isChecked && item.hasIssue {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Issue Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                    
                    TextField("Describe the issue...", text: $item.notes, axis: .vertical)
                        .lineLimit(4)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                        
                        Text("Add Photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Helper extension for partial corner rounding
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct VehicleInspectionView_Previews: PreviewProvider {
    static var previews: some View {
        VehicleInspectionView(isPreTrip: true) { _ in }
    }
} 