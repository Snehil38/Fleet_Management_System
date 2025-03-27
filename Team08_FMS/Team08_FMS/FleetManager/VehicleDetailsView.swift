import SwiftUI
import PhotosUI

// MARK: - Basic Information Section
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

// MARK: - Vehicle Details Section
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
private struct DocumentsSection: View {
    @Binding var pollutionCertificate: Data?
    @Binding var rc: Data?
    @Binding var insurance: Data?
    @Binding var pollutionExpiry: Date
    @Binding var insuranceExpiry: Date
    @Binding var showingPollutionPicker: Bool
    @Binding var showingRCPicker: Bool
    @Binding var showingInsurancePicker: Bool

    var body: some View {
        Section("Required Documents") {
            VStack(spacing: 16) {
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
            }
            .padding(.vertical, 8)
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

// MARK: - Main View
struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vehicleManager: VehicleManager
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isLoadingDetails = false
    @State private var detailLoadError: String? = nil

    var vehicle: Vehicle?
    
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
        !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    init(vehicle: Vehicle? = nil, vehicleManager: VehicleManager) {
        self.vehicle = vehicle
        self.vehicleManager = vehicleManager
        
        if let vehicle = vehicle {
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
            
//            _pollutionCertificate = State(initialValue: vehicle.documents?.pollutionCertificate)
//            _rc = State(initialValue: vehicle.documents?.rc)
//            _insurance = State(initialValue: vehicle.documents?.insurance)
        }
    }
    
    var body: some View {
        Form {
            if vehicle == nil || isEditing {
                // Basic Information Section with inline errors.
                basicInformationSection
                vehicleDetailsSection
                
                // Documents Section
                documentSection
            } else {
                // View mode sections
                readOnlyBasicInfoSection
                readOnlyVehicleDetailsSection
//                readOnlyDocumentsSection
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
//        .onAppear {
//            if let vehicle = vehicle {
//                loadVehicleDetails()
//            }
//        }
        .overlay {
            if isLoadingDetails && vehicle != nil && !isEditing {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView("Loading vehicle details...")
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 3)
            }
        }
    }
    
    // MARK: - UI Components
    
    private var toolbarItems: some ToolbarContent {
        Group {
            if vehicle != nil {
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
            } else {
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
    
    private var documentSection: some View {
        DocumentsSection(
            pollutionCertificate: $pollutionCertificate,
            rc: $rc,
            insurance: $insurance,
            pollutionExpiry: $pollutionExpiry,
            insuranceExpiry: $insuranceExpiry,
            showingPollutionPicker: $showingPollutionPicker,
            showingRCPicker: $showingRCPicker,
            showingInsurancePicker: $showingInsurancePicker
        )
    }
    
    private var readOnlyBasicInfoSection: some View {
        Section("Basic Information") {
            LabeledContent(label:"Name", value: vehicle?.name ?? "")
            LabeledContent(label:"Year", value: "\(vehicle?.year ?? 0)")
            LabeledContent(label:"Make", value: vehicle?.make ?? "")
            LabeledContent(label:"Model", value: vehicle?.model ?? "")
            LabeledContent(label:"VIN", value: vehicle?.vin ?? "")
            LabeledContent(label:"License Plate", value: vehicle?.licensePlate ?? "")
        }
    }
    
    private var readOnlyVehicleDetailsSection: some View {
        Section("Vehicle Details") {
            LabeledContent(label:"Vehicle Type", value: vehicle?.vehicleType.rawValue ?? "")
            LabeledContent(label:"Color", value: vehicle?.color ?? "")
            LabeledContent(label:"Body Type", value: vehicle?.bodyType.rawValue ?? "")
            LabeledContent(label:"Body Subtype", value: vehicle?.bodySubtype ?? "")
            LabeledContent(label:"MSRP", value: "$\(String(format: "%.2f", vehicle?.msrp ?? 0))")
        }
    }
    
    // MARK: - Read-Only Document Section
//    private var readOnlyDocumentsSection: some View {
//        Section("Documents") {
//            if isLoadingDetails {
//                ProgressView("Loading documents...")
//                    .frame(maxWidth: .infinity, alignment: .center)
//                    .padding()
//            } else if let error = detailLoadError {
//                VStack(alignment: .center, spacing: 10) {
//                    Text("Failed to load documents")
//                        .foregroundColor(.red)
//                    Text(error)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    Button("Retry") {
//                        loadVehicleDetails()
//                    }
//                    .buttonStyle(.bordered)
//                }
//                .frame(maxWidth: .infinity, alignment: .center)
//                .padding()
//            } else {
//                // Display document information
//                if let pollution = pollutionCertificate {
//                    HStack {
//                        Text("Pollution Certificate")
//                        Spacer()
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//                    }
//                    Text("Expires: \(pollutionExpiry.formatted(date: .long, time: .omitted))")
//                        .font(.caption)
//                } else {
//                    HStack {
//                        Text("Pollution Certificate")
//                        Spacer()
//                        Text("Not available")
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                if let rc = rc {
//                    HStack {
//                        Text("RC")
//                        Spacer()
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//                    }
//                } else {
//                    HStack {
//                        Text("RC")
//                        Spacer()
//                        Text("Not available")
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                if let insurance = insurance {
//                    HStack {
//                        Text("Insurance")
//                        Spacer()
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(.green)
//                    }
//                    Text("Expires: \(insuranceExpiry.formatted(date: .long, time: .omitted))")
//                        .font(.caption)
//                } else {
//                    HStack {
//                        Text("Insurance")
//                        Spacer()
//                        Text("Not available")
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//        }
//    }
    
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
                if licensePlateEdited && !isLicensePlateValid {
                    Text("License Plate cannot be empty.")
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
        
        if let originalVehicle = vehicle {
            // Build an updated Vehicle using current state values.
            let updatedVehicle = Vehicle(
                id: originalVehicle.id,
                name: name,
                year: Int(year) ?? originalVehicle.year,
                make: make,
                model: model,
                vin: vin,
                licensePlate: licensePlate,
                vehicleType: vehicleType,
                color: color,
                bodyType: bodyType,
                bodySubtype: bodySubtype,
                msrp: Double(msrp) ?? originalVehicle.msrp,
                pollutionExpiry: pollutionExpiry,
                insuranceExpiry: insuranceExpiry,
                status: originalVehicle.status,
                driverId: originalVehicle.driverId
            )
            
            Task {
                defer { isSaving = false }
                do {
                    try await SupabaseDataController.shared.updateVehicle(vehicle: updatedVehicle)
                    await vehicleManager.loadVehiclesAsync()
                } catch {
                    print("Error updating vehicle: \(error.localizedDescription)")
                }
            }
        } else {
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
                } catch {
                    print("Error inserting vehicle: \(error.localizedDescription)")
                }
            }
        }
        
        // Toggle back to view mode if editing; dismiss if adding a new vehicle.
        if isEditing {
            isEditing = false
        } else {
            dismiss()
        }
    }

//    private func loadVehicleDetails() {
//        
//        isLoadingDetails = true
//        detailLoadError = nil
        
//        Task {
//            do {
//                if let fullDetails = try await SupabaseDataController.shared.fetchVehicleDetails(vehicleId: vehicle.id) {
//                    await MainActor.run {
//                        // Only update the document data
//                        pollutionCertificate = fullDetails.documents?.pollutionCertificate
//                        rc = fullDetails.documents?.rc
//                        insurance = fullDetails.documents?.insurance
//                        
//                        isLoadingDetails = false
//                    }
//                } else {
//                    await MainActor.run {
//                        detailLoadError = "Could not find detailed vehicle information"
//                        isLoadingDetails = false
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    detailLoadError = error.localizedDescription
//                    isLoadingDetails = false
//                }
//            }
//        }
//    }
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
        !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        if licensePlateEdited && !isLicensePlateValid {
                            Text("License Plate cannot be empty.")
                                .font(.caption)
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
                    showingInsurancePicker: $showingInsurancePicker
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
            // Document pickers for uploading attachments.
//            .photosPicker(isPresented: $showingPollutionPicker, selection: $selectedPollutionItem)
//            .photosPicker(isPresented: $showingRCPicker, selection: $selectedRCItem)
//            .photosPicker(isPresented: $showingInsurancePicker, selection: $selectedInsuranceItem)
//            .onChange(of: selectedPollutionItem) { _, newItem in
//                Task {
//                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
//                        pollutionCertificate = data
//                    }
//                }
//            }
//            .onChange(of: selectedRCItem) { _, newItem in
//                Task {
//                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
//                        rc = data
//                    }
//                }
//            }
//            .onChange(of: selectedInsuranceItem) { _, newItem in
//                Task {
//                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
//                        insurance = data
//                    }
//                }
//            }
        }
    }

    private func saveVehicle() {
        // Prevent duplicate taps.
        guard !isSaving else { return }
        isSaving = true

//        let documents = VehicleDocuments(
//            pollutionCertificate: pollutionCertificate ?? Data(),
//            rc: rc ?? Data(),
//            insurance: insurance ?? Data()
//        )

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
