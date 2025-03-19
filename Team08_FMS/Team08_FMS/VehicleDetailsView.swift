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
        case .idle:
            return .green
        case .allotted:
            return .blue
        case .maintenance:
            return .orange
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

    var vehicle: Vehicle?
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

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodySubtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pollutionCertificate != nil &&
        rc != nil &&
        insurance != nil
    }

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

            _pollutionCertificate = State(initialValue: vehicle.documents.pollutionCertificate)
            _rc = State(initialValue: vehicle.documents.rc)
            _insurance = State(initialValue: vehicle.documents.insurance)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                if isEditing {
                    BasicInformationSection(
                        name: $name,
                        year: $year,
                        make: $make,
                        model: $model,
                        vin: $vin,
                        licensePlate: $licensePlate
                    )

                    VehicleDetailsSection(
                        vehicleType: $vehicleType,
                        color: $color,
                        bodyType: $bodyType,
                        bodySubtype: $bodySubtype,
                        msrp: $msrp
                    )

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
                } else {
                    // View Mode
                    Section("Basic Information") {
                        LabeledContent("Name", value: name)
                        LabeledContent("Year", value: year)
                        LabeledContent("Make", value: make)
                        LabeledContent("Model", value: model)
                        LabeledContent("VIN", value: vin)
                        LabeledContent("License Plate", value: licensePlate)
                    }

                    Section("Vehicle Details") {
                        LabeledContent("Type", value: vehicleType.rawValue.capitalized)
                        LabeledContent("Color", value: color)
                        LabeledContent("Body Type", value: bodyType.rawValue.capitalized)
                        LabeledContent("Body Subtype", value: bodySubtype)
                        LabeledContent("MSRP", value: msrp)
                    }

                    Section("Documents") {
                        LabeledContent("Pollution Certificate", value: pollutionCertificate != nil ? "Attached" : "Not Attached")
                        LabeledContent("RC", value: rc != nil ? "Attached" : "Not Attached")
                        LabeledContent("Insurance", value: insurance != nil ? "Attached" : "Not Attached")
                        LabeledContent("Pollution Expiry", value: pollutionExpiry.formatted(date: .long, time: .omitted))
                        LabeledContent("Insurance Expiry", value: insuranceExpiry.formatted(date: .long, time: .omitted))
                    }
                }

                if let vehicle = vehicle {
                    StatusSection(
                        status: vehicle.status,
                        driverName: nil // TODO: Get driver name from driver ID
                    )
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vehicle != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditing {
                            Button("Save") {
                                saveVehicle()
                            }
                            .disabled(!isFormValid)
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
                        .disabled(!isFormValid)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .photosPicker(isPresented: $showingPollutionPicker,
                         selection: $selectedPollutionItem)
            .photosPicker(isPresented: $showingRCPicker,
                         selection: $selectedRCItem)
            .photosPicker(isPresented: $showingInsurancePicker,
                         selection: $selectedInsuranceItem)
            .onChange(of: selectedPollutionItem) { oldValue, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        pollutionCertificate = data
                    }
                }
            }
            .onChange(of: selectedRCItem) { oldValue, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        rc = data
                    }
                }
            }
            .onChange(of: selectedInsuranceItem) { oldValue, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        insurance = data
                    }
                }
            }
        }
    }

    private func saveVehicle() {
        let documents = VehicleDocuments(
            pollutionCertificate: pollutionCertificate ?? Data(),
            rc: rc ?? Data(),
            insurance: insurance ?? Data()
        )

        if let vehicle = vehicle {
            vehicleManager.updateVehicle(
                vehicle,
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
                documents: documents
            )
        } else {
            vehicleManager.addVehicle(
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
                documents: documents
            )
        }
        
        if isEditing {
            isEditing = false
        } else {
            dismiss()
        }
    }
}
