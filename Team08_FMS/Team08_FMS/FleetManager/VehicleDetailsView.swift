import SwiftUI
import PhotosUI
import PDFKit

private struct BasicInformationSection: View {
    @Binding var name: String
    @Binding var year: String
    @Binding var make: String
    @Binding var model: String
    @Binding var vin: String
    @Binding var licensePlate: String

    var body: some View {
        Section("Basic Information") {
            TextField("Name", text: $name)
            TextField("Year", text: $year)
                .textContentType(.birthdateYear)
                .keyboardType(.numberPad)
            TextField("Make", text: $make)
            TextField("Model", text: $model)
            TextField("VIN/SN", text: $vin)
            TextField("License Plate", text: $licensePlate)
        }
    }
}

private struct VehicleDetailsSection: View {
    @Binding var vehicleType: VehicleType
    @Binding var color: String
    @Binding var bodyType: BodyType
    @Binding var bodySubtype: String
    @Binding var msrp: String

    var body: some View {
        Section("Vehicle Details") {
            Picker("Vehicle Type", selection: $vehicleType) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            TextField("Color", text: $color)
            Picker("Body Type", selection: $bodyType) {
                ForEach(BodyType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            TextField("Body Subtype", text: $bodySubtype)
            TextField("MSRP", text: $msrp)
                .keyboardType(.decimalPad)
        }
    }
}

// MARK: - Expiry Dates Section
private struct ExpiryDatesSection: View {
    @Binding var pollutionExpiry: Date
    @Binding var insuranceExpiry: Date

    var body: some View {
        Section("Expiry Dates") {
            DatePicker("Pollution Expiry", selection: $pollutionExpiry, displayedComponents: .date)
            DatePicker("Insurance Expiry", selection: $insuranceExpiry, displayedComponents: .date)
        }
    }
}

// MARK: - Status Section
private struct StatusSection: View {
    let status: VehicleStatus
    let driverName: String?

    var body: some View {
        Section("Status Information") {
            HStack {
                Text("Status:")
                Spacer()
                Text(status.rawValue)
                    .foregroundColor(statusColor(for: status))
            }
            if let driverName = driverName {
                HStack {
                    Text("Assigned Driver:")
                    Spacer()
                    Text(driverName)
                }
            }
        }
    }

    private func statusColor(for status: VehicleStatus) -> Color {
        switch status {
        case .available:
            return .green
        case .inService:
            return .blue
        case .underMaintenance:
            return .orange
        case .decommissioned:
            return .red
        }
    }
}

// MARK: - Documents Section
struct DocumentsSection: View {
    @Binding var pollutionCertificate: Data?
    @Binding var rc: Data?
    @Binding var insurance: Data?
    @Binding var pollutionExpiry: Date
    @Binding var insuranceExpiry: Date
    @Binding var showingPollutionPicker: Bool
    @Binding var showingRCPicker: Bool
    @Binding var showingInsurancePicker: Bool
    @Binding var showingDeliveryReceipt: Bool
    @Binding var pdfData: Data?
    @Binding var pdfError: String?
    @Binding var showingPDFError: Bool
    let currentTrip: Trip?
    
    var body: some View {
        Section("Documents") {
            DocumentUploadRow(
                title: "Pollution Certificate",
                data: pollutionCertificate,
                expiryDate: pollutionExpiry,
                showPicker: $showingPollutionPicker
            )

            DocumentUploadRow(
                title: "RC",
                data: rc,
                showPicker: $showingRCPicker
            )

            DocumentUploadRow(
                title: "Insurance",
                data: insurance,
                expiryDate: insuranceExpiry,
                showPicker: $showingInsurancePicker
            )
            
            if let trip = currentTrip {
                Button(action: {
                    do {
                        pdfData = try TripDataController.shared.generateDeliveryReceipt(for: trip)
                        showingDeliveryReceipt = true
                    } catch {
                        pdfError = error.localizedDescription
                        showingPDFError = true
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("Delivery Receipt")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

private struct DocumentUploadRow: View {
    let title: String
    let data: Data?
    var expiryDate: Date?
    @Binding var showPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let _ = data {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if let expiryDate = expiryDate {
                DatePicker("Expiry Date", selection: .constant(expiryDate), displayedComponents: .date)
                    .font(.subheadline)
            }

            Button(action: { showPicker = true }) {
                HStack {
                    Image(systemName: data == nil ? "square.and.arrow.up.circle.fill" : "arrow.triangle.2.circlepath")
                    Text(data == nil ? "Upload Document" : "Replace Document")
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct PDFViewer: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - Main View
struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vehicleManager: VehicleManager
    @StateObject private var maintenanceStore = MaintenancePersonnelDataStore()
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isLoadingDetails = false
    @State private var detailLoadError: String? = nil

    let vehicle: Vehicle
    
    // Form fields
    @State private var name: String = ""
    @State private var year: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var vin: String = ""
    @State private var licensePlate: String = ""
    @State private var vehicleType: VehicleType = .truck
    @State private var color: String = ""
    @State private var bodyType: BodyType = .cargo
    @State private var bodySubtype: String = ""
    @State private var msrp: String = ""
    @State private var pollutionExpiry: Date = Date()
    @State private var insuranceExpiry: Date = Date()
    
    @State private var pollutionCertificate: Data?
    @State private var rc: Data?
    @State private var insurance: Data?
    
    @State private var showingPollutionPicker = false
    @State private var showingRCPicker = false
    @State private var showingInsurancePicker = false
    
    @State private var selectedPollutionItem: PhotosPickerItem?
    @State private var selectedRCItem: PhotosPickerItem?
    @State private var selectedInsuranceItem: PhotosPickerItem?
    
    // MARK: - Field "Touched" States
    @State private var nameEdited = false
    @State private var yearEdited = false
    @State private var makeEdited = false
    @State private var modelEdited = false
    @State private var vinEdited = false
    @State private var licensePlateEdited = false
    @State private var bodySubtypeEdited = false
    @State private var msrpEdited = false
    
    // MARK: - Field Validations
    
    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Only letters (upper and lowercase) and spaces allowed.
        let regex = "^[A-Za-z ]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }
    
    private var isYearValid: Bool {
        if let y = Int(year) {
            let currentYear = Calendar.current.component(.year, from: Date())
            return y >= 1900 && y <= currentYear
        }
        return false
    }
    
    private var isMakeValid: Bool {
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isModelValid: Bool {
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isVINValid: Bool {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count == 17
    }
    
    private var isLicensePlateValid: Bool {
        // This regex matches two letters, two numbers, two letters, and four numbers.
        let licensePlateRegex = "^[A-Za-z]{2}[0-9]{2}[A-Za-z]{2}[0-9]{4}$"
        return NSPredicate(format: "SELF MATCHES %@", licensePlateRegex).evaluate(with: licensePlate)
    }
    
    private var isBodySubtypeValid: Bool {
        !bodySubtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isMSRPValid: Bool {
        if let msrpValue = Double(msrp) {
            return msrpValue > 0
        }
        return false
    }
    
    // Overall form validity using all validations.
    private var isFormValid: Bool {
        isNameValid &&
        isYearValid &&
        isMakeValid &&
        isModelValid &&
        isVINValid &&
        isLicensePlateValid &&
        isBodySubtypeValid &&
        isMSRPValid
    }
    
    // Initialize with an existing vehicle if provided
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        
        // Initialize state properties with vehicle data
        _name = State(initialValue: vehicle.name)
        _year = State(initialValue: String(vehicle.year))
        _make = State(initialValue: vehicle.make)
        _model = State(initialValue: vehicle.model)
        _vin = State(initialValue: vehicle.vin)
        _licensePlate = State(initialValue: vehicle.licensePlate)
        _vehicleType = State(initialValue: vehicle.vehicleType)
        _color = State(initialValue: vehicle.color)
        _bodyType = State(initialValue: vehicle.bodyType)
        _bodySubtype = State(initialValue: vehicle.bodySubtype)
        _msrp = State(initialValue: String(vehicle.msrp))
        _pollutionExpiry = State(initialValue: vehicle.pollutionExpiry)
        _insuranceExpiry = State(initialValue: vehicle.insuranceExpiry)
    }
    
    @State private var showingDeliveryReceipt = false
    @State private var currentTrip: Trip?
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    @State private var pdfData: Data? = nil
    
    var body: some View {
        Form {
            if isEditing {
                // Basic Information Section with inline errors.
                basicInformationSection
                vehicleDetailsSection
                
                // Documents Section
//                documentSection
            } else {
                // View mode sections
                readOnlyBasicInfoSection
                readOnlyVehicleDetailsSection
                serviceRequestDetailsSection
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarItems
        }
        .photosPicker(isPresented: $showingPollutionPicker, selection: $selectedPollutionItem)
        .photosPicker(isPresented: $showingRCPicker, selection: $selectedRCItem)
        .photosPicker(isPresented: $showingInsurancePicker, selection: $selectedInsuranceItem)
        .onChange(of: selectedPollutionItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    pollutionCertificate = data
                }
            }
        }
        .onChange(of: selectedRCItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    rc = data
                }
            }
        }
        .onChange(of: selectedInsuranceItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    insurance = data
                }
            }
        }
        .onAppear {
            // Find if this vehicle has any current trip
            currentTrip = TripDataController.shared.allTrips.first(where: { 
                $0.vehicleDetails.id == vehicle.id && 
                ($0.status == .inProgress || $0.status == .delivered)
            })
        }
        .task {
            // Initial load of vehicle data
            vehicleManager.loadVehicles()
            CrewDataController.shared.update()
        }
        .overlay {
            if isLoadingDetails && !isEditing {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView("Loading vehicle details...")
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 3)
            }
        }
        .sheet(isPresented: $showingDeliveryReceipt) {
            NavigationView {
                if let data = pdfData {
                    PDFViewer(data: data)
                        .navigationTitle("Delivery Receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDeliveryReceipt = false
                                }
                            }
                        }
                }
            }
        }
        .alert("Error", isPresented: $showingPDFError) {
            Button("OK") {
                showingPDFError = false
            }
        } message: {
            Text(pdfError ?? "Failed to generate delivery receipt")
        }
    }
    
    // MARK: - UI Components
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isFormValid || isSaving)
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
        }
    }
    
    private var documentSection: some View {
        DocumentsSection(
            pollutionCertificate: $pollutionCertificate,
            rc: $rc,
            insurance: $insurance,
            pollutionExpiry: $pollutionExpiry,
            insuranceExpiry: $insuranceExpiry,
            showingPollutionPicker: $showingPollutionPicker,
            showingRCPicker: $showingRCPicker,
            showingInsurancePicker: $showingInsurancePicker,
            showingDeliveryReceipt: $showingDeliveryReceipt,
            pdfData: $pdfData,
            pdfError: $pdfError,
            showingPDFError: $showingPDFError,
            currentTrip: currentTrip
        )
    }
    
    private var readOnlyBasicInfoSection: some View {
        Section("Basic Information") {
            LabeledContent(label: "Name", value: vehicle.name)
            LabeledContent(label: "Year", value: "\(vehicle.year)")
            LabeledContent(label: "Make", value: vehicle.make)
            LabeledContent(label: "Model", value: vehicle.model)
            LabeledContent(label: "VIN", value: vehicle.vin)
            LabeledContent(label: "License Plate", value: vehicle.licensePlate)
        }
    }
    
    private var readOnlyVehicleDetailsSection: some View {
        Section("Vehicle Details") {
            LabeledContent(label: "Vehicle Type", value: vehicle.vehicleType.rawValue)
            LabeledContent(label: "Color", value: vehicle.color)
            LabeledContent(label: "Body Type", value: vehicle.bodyType.rawValue)
            LabeledContent(label: "Body Subtype", value: vehicle.bodySubtype)
            LabeledContent(label: "MSRP", value: "$\(String(format: "%.2f", vehicle.msrp))")
            
            // Add odometer reading
            let totalDistance = TripDataController.shared.allTrips
                .filter { $0.vehicleDetails.id == vehicle.id && $0.status == .delivered }
                .reduce(0.0) { sum, trip in
                    if let estimatedDistance = Double(trip.distance.replacingOccurrences(of: " km", with: "")) {
                        return sum + estimatedDistance
                    }
                    return sum
                }
            LabeledContent(label: "Odometer", value: String(format: "%.1f km", totalDistance))
        }
    }
    
    // Add Service Request Details Section
    private var serviceRequestDetailsSection: some View {
        @State var serviceRequests = maintenanceStore.serviceRequests
            .filter { $0.vehicleId == vehicle.id }
        
        return Section("Service Request Details") {
            if serviceRequests.isEmpty {
                Text("No service requests found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(serviceRequests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        // Service Type and Status
                        HStack {
                            Text(request.serviceType.rawValue)
                                .font(.headline)
                            Spacer()
                            Text(request.status.rawValue)
                                .foregroundColor(statusColor(for: request.status))
                                .font(.subheadline)
                        }
                        
                        // Issue Type
                        if let issueType = request.issueType {
                            Text("Issue Type: \(issueType)")
                                .font(.subheadline)
                        }
                        
                        // Due Date
                        Text("Due: \(request.dueDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Total Cost if there are expenses
                        if request.totalCost > 0 {
                            HStack {
                                Spacer()
                                Text("Total Cost: $\(request.totalCost, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if !request.notes.isEmpty {
                            Text("Notes: \(request.notes)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .onAppear {
                        // Fetch expenses for this request when it appears
                        Task {
                            do {
                                let expenses = try await maintenanceStore.fetchExpenses(for: request.id)
                                let totalCost = expenses.reduce(0.0) { $0 + $1.amount }
                                if let index = maintenanceStore.serviceRequests.firstIndex(where: { $0.id == request.id }) {
                                    await MainActor.run {
                                        maintenanceStore.serviceRequests[index].totalCost = totalCost
                                    }
                                }
                            } catch {
                                print("Error fetching expenses: \(error)")
                            }
                        }
                    }
                    
                    if request.id != serviceRequests.last?.id {
                        Divider()
                    }
                }
            }
        }
        .onAppear {
            // Refresh service requests when the section appears
            Task {
                await maintenanceStore.loadData()
            }
        }
    }
    
    private func statusColor(for status: ServiceRequestStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .assigned:
            return .blue
        case .inProgress:
            return .green
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    // Extract complex section into a separate computed property
    private var basicInformationSection: some View {
        Section("Basic Information") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, _ in nameEdited = true }
                if nameEdited && !isNameValid {
                    Text("Name cannot be empty and must not contain numbers.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Year", text: $year)
                    .keyboardType(.numberPad)
                    .onChange(of: year) { _, _ in yearEdited = true }
                if yearEdited && !isYearValid {
                    Text("Year must be a number between 1900 and the current year.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Make", text: $make)
                    .onChange(of: make) { _, _ in makeEdited = true }
                if makeEdited && !isMakeValid {
                    Text("Make cannot be empty.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Model", text: $model)
                    .onChange(of: model) { _, _ in modelEdited = true }
                if modelEdited && !isModelValid {
                    Text("Model cannot be empty.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("VIN", text: $vin)
                    .onChange(of: vin) { _, _ in vinEdited = true }
                if vinEdited && !isVINValid {
                    Text("VIN must be exactly 17 characters.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("License Plate", text: $licensePlate)
                    .onChange(of: licensePlate) { _, _ in licensePlateEdited = true }
                    .autocapitalization(.allCharacters)
                if licensePlateEdited && !isLicensePlateValid {
                    Text("License Plate must follow the format KA01CA1111.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var vehicleDetailsSection: some View {
        Section("Vehicle Details") {
            Picker("Vehicle Type", selection: $vehicleType) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            
            TextField("Color", text: $color)
            
            Picker("Body Type", selection: $bodyType) {
                ForEach(BodyType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Body Subtype", text: $bodySubtype)
                    .onChange(of: bodySubtype) { _, _ in bodySubtypeEdited = true }
                if bodySubtypeEdited && !isBodySubtypeValid {
                    Text("Body Subtype cannot be empty.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("MSRP", text: $msrp)
                    .keyboardType(.decimalPad)
                    .onChange(of: msrp) { _, _ in msrpEdited = true }
                if msrpEdited && !isMSRPValid {
                    Text("MSRP must be a positive number.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func saveVehicle() {
        // Prevent duplicate taps.
        guard !isSaving else { return }
        isSaving = true
        
        // Build an updated Vehicle using current state values.
        let updatedVehicle = Vehicle(
            id: vehicle.id,
            name: name,
            year: Int(year) ?? vehicle.year,
            make: make,
            model: model,
            vin: vin,
            licensePlate: licensePlate,
            vehicleType: vehicleType,
            color: color,
            bodyType: bodyType,
            bodySubtype: bodySubtype,
            msrp: Double(msrp) ?? vehicle.msrp,
            pollutionExpiry: pollutionExpiry,
            insuranceExpiry: insuranceExpiry,
            status: vehicle.status,
            driverId: vehicle.driverId
        )
        
        Task {
            defer { isSaving = false }
            do {
                try await SupabaseDataController.shared.updateVehicle(vehicle: updatedVehicle)
                await vehicleManager.loadVehiclesAsync()
                isEditing = false
            } catch {
                print("Error updating vehicle: \(error.localizedDescription)")
            }
        }
    }
}

struct VehicleSaveView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vehicleManager: VehicleManager

    @State private var name: String = ""
    @State private var year: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var vin: String = ""
    @State private var licensePlate: String = ""
    @State private var vehicleType: VehicleType = .truck
    @State private var color: String = ""
    @State private var bodyType: BodyType = .cargo
    @State private var bodySubtype: String = ""
    @State private var msrp: String = ""
    @State private var pollutionExpiry: Date = Date()
    @State private var insuranceExpiry: Date = Date()

    @State private var pollutionCertificate: Data?
    @State private var rc: Data?
    @State private var insurance: Data?

    @State private var showingPollutionPicker = false
    @State private var showingRCPicker = false
    @State private var showingInsurancePicker = false
    @State private var showingDeliveryReceipt = false
    @State private var pdfData: Data? = nil
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false

    @State private var selectedPollutionItem: PhotosPickerItem?
    @State private var selectedRCItem: PhotosPickerItem?
    @State private var selectedInsuranceItem: PhotosPickerItem?

    // MARK: - Touched State Variables
    @State private var nameEdited = false
    @State private var yearEdited = false
    @State private var makeEdited = false
    @State private var modelEdited = false
    @State private var vinEdited = false
    @State private var licensePlateEdited = false
    @State private var bodySubtypeEdited = false
    @State private var msrpEdited = false
    
    // MARK: - Save Operation State
    @State private var isSaving = false

    // MARK: - Field Validations

    // Name must not be empty, must not start with a number, and must not contain any digits.
    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Only letters (upper and lowercase) and spaces allowed.
        let regex = "^[A-Za-z ]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }

    private var isYearValid: Bool {
        if let y = Int(year) {
            let currentYear = Calendar.current.component(.year, from: Date())
            return y >= 1900 && y <= currentYear
        }
        return false
    }

    private var isMakeValid: Bool {
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isModelValid: Bool {
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isVINValid: Bool {
        let trimmed = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count == 17
    }

    private var isLicensePlateValid: Bool {
        // This regex matches two letters, two numbers, two letters, and four numbers.
        let licensePlateRegex = "^[A-Za-z]{2}[0-9]{2}[A-Za-z]{2}[0-9]{4}$"
        return NSPredicate(format: "SELF MATCHES %@", licensePlateRegex).evaluate(with: licensePlate)
    }

    private var isBodySubtypeValid: Bool {
        !bodySubtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isMSRPValid: Bool {
        if let msrpValue = Double(msrp) {
            return msrpValue > 0
        }
        return false
    }

    // Overall form is valid if all validations pass.
    private var isFormValid: Bool {
        isNameValid &&
        isYearValid &&
        isMakeValid &&
        isModelValid &&
        isVINValid &&
        isLicensePlateValid &&
        isBodySubtypeValid &&
        isMSRPValid
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, _ in nameEdited = true }
                        if nameEdited && !isNameValid {
                            Text("Name must not be empty or contain numbers.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Year", text: $year)
                            .keyboardType(.numberPad)
                            .onChange(of: year) { _, _ in yearEdited = true }
                        if yearEdited && !isYearValid {
                            Text("Year must be a number between 1900 and the current year.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Make", text: $make)
                            .onChange(of: make) { _, _ in makeEdited = true }
                        if makeEdited && !isMakeValid {
                            Text("Make cannot be empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Model", text: $model)
                            .onChange(of: model) { _, _ in modelEdited = true }
                        if modelEdited && !isModelValid {
                            Text("Model cannot be empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("VIN", text: $vin)
                            .onChange(of: vin) { _, _ in vinEdited = true }
                        if vinEdited && !isVINValid {
                            Text("VIN must be exactly 17 characters.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("License Plate", text: $licensePlate)
                            .onChange(of: licensePlate) { _, _ in licensePlateEdited = true }
                            .autocapitalization(.allCharacters)
                        if licensePlateEdited && !isLicensePlateValid {
                            Text("License Plate must follow the format KA01CA1111.")                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section(header: Text("Vehicle Details")) {
                    Picker("Vehicle Type", selection: $vehicleType) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }
                    
                    TextField("Color", text: $color)
                    
                    Picker("Body Type", selection: $bodyType) {
                        ForEach(BodyType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Body Subtype", text: $bodySubtype)
                            .onChange(of: bodySubtype) { _, _ in bodySubtypeEdited = true }
                        if bodySubtypeEdited && !isBodySubtypeValid {
                            Text("Body Subtype cannot be empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("MSRP", text: $msrp)
                            .keyboardType(.decimalPad)
                            .onChange(of: msrp) { _, _ in msrpEdited = true }
                        if msrpEdited && !isMSRPValid {
                            Text("MSRP must be a positive number.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Documents Section remains unchanged.
                DocumentsSection(
                    pollutionCertificate: $pollutionCertificate,
                    rc: $rc,
                    insurance: $insurance,
                    pollutionExpiry: $pollutionExpiry,
                    insuranceExpiry: $insuranceExpiry,
                    showingPollutionPicker: $showingPollutionPicker,
                    showingRCPicker: $showingRCPicker,
                    showingInsurancePicker: $showingInsurancePicker,
                    showingDeliveryReceipt: $showingDeliveryReceipt,
                    pdfData: $pdfData,
                    pdfError: $pdfError,
                    showingPDFError: $showingPDFError,
                    currentTrip: nil
                )
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isFormValid || isSaving)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveVehicle() {
        // Prevent duplicate taps.
        guard !isSaving else { return }
        isSaving = true

        let newVehicle = Vehicle(
            name: name,
            year: Int(year) ?? 0,
            make: make,
            model: model,
            vin: vin,
            licensePlate: licensePlate,
            vehicleType: vehicleType,
            color: color,
            bodyType: bodyType,
            bodySubtype: bodySubtype,
            msrp: Double(msrp) ?? 0,
            pollutionExpiry: pollutionExpiry,
            insuranceExpiry: insuranceExpiry,
            status: .available
        )

        Task {
            defer { isSaving = false }
            do {
                try await SupabaseDataController.shared.insertVehicle(vehicle: newVehicle)
                await vehicleManager.loadVehiclesAsync()
                dismiss()
            } catch {
                print("Error inserting vehicle: \(error.localizedDescription)")
            }
        }
    }
}
