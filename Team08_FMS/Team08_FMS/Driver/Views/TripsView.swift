import SwiftUI
import CoreLocation
import UIKit
import PDFKit

struct TripsView: View {
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @State private var selectedFilter: TripFilter = .upcoming
    @State private var showingError = false
    
    enum TripFilter {
        case upcoming, delivered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                Text("Upcoming (\(tripController.upcomingTrips.count))").tag(TripFilter.upcoming)
                Text("Delivered (\(tripController.recentDeliveries.count))").tag(TripFilter.delivered)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Trips List
            if tripController.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading trips...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTrips.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredTrips) { trip in
                            TripCard(trip: trip)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await tripController.refreshTrips()
                }
            }
        }
        .navigationTitle("Trips")
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            if let error = tripController.error {
                switch error {
                case .fetchError(let message):
                    Text(message)
                case .decodingError(let message):
                    Text(message)
                case .vehicleError(let message):
                    Text(message)
                case .updateError(let message):
                    Text(message)
                case .locationError(let message):
                    Text(message)
                }
            } else {
                Text("An unexpected error occurred.")
            }
        }
        .onChange(of: tripController.error) { error, _ in
            showingError = error != nil
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .upcoming:
            return "clock.arrow.circlepath"
        case .delivered:
            return "checkmark.circle"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .upcoming:
            return "No Upcoming Trips"
        case .delivered:
            return "No Completed Deliveries"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .upcoming:
            return "You don't have any upcoming trips scheduled."
        case .delivered:
            return "You haven't completed any deliveries yet."
        }
    }
    
    private var filteredTrips: [Trip] {
        switch selectedFilter {
        case .upcoming:
            return availabilityManager.isAvailable ? tripController.upcomingTrips : []
        case .delivered:
            // Convert recent deliveries to Trip objects with improved information
            return tripController.recentDeliveries.map { delivery in
                createTripFromDelivery(delivery) ?? {
                    // Create a fallback vehicle
                    let vehicle = Vehicle(
                        name: "Unknown Vehicle",
                        year: 0,
                        make: "Unknown",
                        model: "Unknown",
                        vin: "Unknown",
                        licensePlate: "Unknown",
                        vehicleType: .truck,
                        color: "Unknown",
                        bodyType: .cargo,
                        bodySubtype: "Unknown",
                        msrp: 0.0,
                        pollutionExpiry: Date(),
                        insuranceExpiry: Date(),
                        status: .available
                    )
                    
                    // Create a fallback SupabaseTrip
                    let supabaseTrip = SupabaseTrip(
                        id: UUID(),
                        destination: "Unknown Location",
                        trip_status: "pending",
                        has_completed_pre_trip: false,
                        has_completed_post_trip: false,
                        vehicle_id: vehicle.id,
                        driver_id: nil,
                        secondary_driver_id: nil,
                        start_time: nil,
                        end_time: nil,
                        notes: "No notes available",
                        created_at: Date(),
                        updated_at: Date(),
                        is_deleted: false,
                        start_latitude: 0,
                        start_longitude: 0,
                        end_latitude: 0,
                        end_longitude: 0,
                        pickup: "Unknown Address",
                        estimated_distance: 0,
                        estimated_time: nil
                    )
                    
                    return Trip(from: supabaseTrip, vehicle: vehicle)
                }()
            }
        }
    }
    
    // Helper function to create Trip from DeliveryDetails
    private func createTripFromDelivery(_ delivery: DeliveryDetails) -> Trip? {
        var tripName = delivery.id.uuidString
        var cargoType = "General Cargo"
        var distance = "N/A"
        var startingPoint = ""
        var deliveryNotes = delivery.notes
        var estimatedDistance: Double? = nil
        var estimatedTime: Double? = nil
        
        // Parse notes for additional information
        for line in delivery.notes.components(separatedBy: .newlines) {
            if line.hasPrefix("Trip:") {
                tripName = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("Cargo:") {
                cargoType = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("Distance:") || line.hasPrefix("Estimated Distance:") {
                let prefix = line.hasPrefix("Distance:") ? "Distance:" : "Estimated Distance:"
                distance = String(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
                // Extract numeric value for estimated_distance
                if let numericDistance = Double(distance.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    estimatedDistance = numericDistance
                }
            } else if line.hasPrefix("From:") {
                startingPoint = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("ETA:") || line.hasPrefix("Estimated Time:") {
                let prefix = line.hasPrefix("ETA:") ? "ETA:" : "Estimated Time:"
                let etaString = String(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
                // Parse ETA string to get minutes
                if let minutes = parseETAToMinutes(etaString) {
                    estimatedTime = Double(minutes) / 60.0 // Convert to hours
                }
            }
        }
        
        // Create a mock vehicle for the delivery
        let vehicle = Vehicle(
            name: "Vehicle",
            year: 2023,
            make: "Unknown",
            model: "Unknown",
            vin: "Unknown",
            licensePlate: delivery.vehicle,
            vehicleType: .truck,
            color: "Unknown",
            bodyType: .cargo,
            bodySubtype: "Unknown",
            msrp: 0.0,
            pollutionExpiry: Date(),
            insuranceExpiry: Date(),
            status: .available
        )
        
        // Create a SupabaseTrip with the delivery information
        let supabaseTrip = SupabaseTrip(
            id: delivery.id,
            destination: delivery.location,
            trip_status: "delivered",
            has_completed_pre_trip: true,
            has_completed_post_trip: true,
            vehicle_id: vehicle.id,
            driver_id: nil,
            secondary_driver_id: nil,
            start_time: nil,
            end_time: nil,
            notes: """
                   Trip: \(tripName)
                   Cargo Type: \(cargoType)
                   Estimated Distance: \(distance)
                   Estimated Time: \(estimatedTime.map { "\(Int($0))h \(Int(($0 - Double(Int($0))) * 60))m" } ?? "N/A")
                   From: \(startingPoint)
                   \(deliveryNotes)
                   """,
            created_at: Date(),
            updated_at: Date(),
            is_deleted: false,
            start_latitude: 0,
            start_longitude: 0,
            end_latitude: 0,
            end_longitude: 0,
            pickup: startingPoint.isEmpty ? delivery.location : startingPoint,
            estimated_distance: estimatedDistance,
            estimated_time: estimatedTime
        )
        
        return Trip(from: supabaseTrip, vehicle: vehicle)
    }
    
    // Helper function to parse ETA string to minutes
    private func parseETAToMinutes(_ etaString: String) -> Int? {
        let components = etaString.lowercased().components(separatedBy: CharacterSet.letters)
        let numbers = components.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        if etaString.contains("h") && etaString.contains("m") {
            // Format: "Xh Ym"
            guard numbers.count >= 2 else { return nil }
            return numbers[0] * 60 + numbers[1]
        } else if etaString.contains("h") {
            // Format: "Xh"
            guard let hours = numbers.first else { return nil }
            return hours * 60
        } else {
            // Format: "X mins" or "X min"
            guard let minutes = numbers.first else { return nil }
            return minutes
        }
    }
}

struct TripCard: View {
    let trip: Trip
    @StateObject private var tripController = TripDataController.shared
    @State private var showingDetails = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
                
                if !trip.eta.isEmpty && trip.status != .delivered {
                    Text(trip.eta)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(trip.destination)
                .font(.title3)
                .fontWeight(.semibold)
            
            if let pickup = trip.pickup {
                Text(pickup)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Cargo Type
                if let notes = trip.notes,
                   let cargoType = notes.components(separatedBy: "Cargo Type:").last?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text("Cargo Type:")
                            .foregroundColor(.gray)
                        Text(cargoType)
                    }
                    .font(.subheadline)
                }
                
                // Distance
                if !trip.distance.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("Distance:")
                            .foregroundColor(.gray)
                        Text(trip.distance)
                    }
                    .font(.subheadline)
                }
                
                // Pickup
                if let pickup = trip.pickup {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text("Pickup:")
                            .foregroundColor(.gray)
                        Text(pickup)
                    }
                    .font(.subheadline)
                }
            }
            
            // Action buttons based on status
            if trip.status != .delivered {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        Task {
                            do {
                                try await tripController.startTrip(trip: trip)
                            } catch {
                                alertMessage = "You have an active trip in progress. Please complete the current trip before starting a new one. This trip will be automatically activated after completing the current trip."
                                showingAlert = true
                            }
                        }
                    }) {
                        Text("Start Trip")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            TripDetailsView(trip: trip)
        }
        .alert("Active Trip in Progress", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Completed"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .inProgress:
            return .blue
        case .pending:
            return .green
        case .delivered:
            return .gray
        case .assigned:
            return .yellow
        }
    }
}

struct TripDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let trip: Trip
    @StateObject private var chatViewModel: ChatViewModel
    @State private var isGeneratingPDF = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    @State private var showingDeliveryReceipt = false
    @State private var receiptData: Data?
    
    init(trip: Trip) {
        self.trip = trip
        self._chatViewModel = StateObject(wrappedValue: ChatViewModel(recipientId: UUID(), recipientType: .driver))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Trip Information")) {
                    TripDetailRow(icon: "number", title: "Trip ID", value: trip.id.uuidString)
                    TripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                    TripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
                    if !trip.eta.isEmpty {
                        TripDetailRow(icon: "clock.fill", title: "ETA", value: trip.eta)
                    }
                    if !trip.distance.isEmpty {
                        TripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                    }
                }
                
                Section(header: Text("Vehicle Information")) {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                    if trip.vehicleDetails.make != "Unknown" {
                        TripDetailRow(icon: "car.2.fill", title: "Make & Model", value: "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model)")
                    }
                }
                
                // Delivery status section for completed trips
                if trip.status == .delivered {
                    Section(header: Text("Delivery Status")) {
                        TripDetailRow(icon: "checkmark.circle.fill", title: "Status", value: "Completed")
                        TripDetailRow(icon: "clock.badge.checkmark.fill", title: "Pre-Trip Inspection", value: "Completed")
                        TripDetailRow(icon: "checkmark.shield.fill", title: "Post-Trip Inspection", value: "Completed")
                    }
                    
                    Section(header: Text("PROOF OF DELIVERY")) {
                        Button(action: {
                            generateDeliveryReceipt()
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Delivery Receipt")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: generateAndDownloadPDF) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                    .foregroundColor(.blue)
                                Text("Download Chat History")
                                    .foregroundColor(.blue)
                                Spacer()
                                if isGeneratingPDF {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .disabled(isGeneratingPDF)
                    }
                } else {
                    // Status section for non-completed trips
                    Section(header: Text("Status")) {
                        TripDetailRow(icon: statusIcon, title: "Current Status", value: statusText)
                        
                        if trip.status == .inProgress {
                            TripDetailRow(
                                icon: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "circle",
                                title: "Pre-Trip Inspection",
                                value: trip.hasCompletedPreTrip ? "Completed" : "Required"
                            )
                            
                            TripDetailRow(
                                icon: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "circle",
                                title: "Post-Trip Inspection",
                                value: trip.hasCompletedPostTrip ? "Completed" : "Required"
                            )
                        }
                    }
                }
                
                // Trip notes section
                if let notes = trip.notes, !notes.isEmpty {
                    Section(header: Text("Notes")) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = pdfURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingDeliveryReceipt) {
                if let data = receiptData {
                    TripDeliveryReceiptViewer(data: data)
                }
            }
            .task {
                // Get fleet manager ID and load chat messages
                do {
                    let fleetManagers = try await SupabaseDataController.shared.fetchFleetManagers()
                    if let fleetManager = fleetManagers.first,
                       let fleetManagerId = fleetManager.userID {
                        // Update the existing chatViewModel with the correct fleet manager ID
                        await MainActor.run {
                            // Create a new ChatViewModel with the correct fleet manager ID
                            let newViewModel = ChatViewModel(recipientId: fleetManagerId, recipientType: .driver)
                            // Load messages
                            Task {
                                await newViewModel.loadMessages()
                                // Update our chatViewModel with the loaded messages
                                chatViewModel.messages = newViewModel.messages
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to load fleet manager: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
        }
    }
    
    private func generateDeliveryReceipt() {
        print("Generating delivery receipt...")
        do {
            let pdfMetaData = [
                kCGPDFContextCreator: "FMS App",
                kCGPDFContextAuthor: "Driver App",
                kCGPDFContextTitle: "Delivery Receipt"
            ]
            
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = pdfMetaData as [String: Any]
            
            let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
            
            let pdfData = try renderer.pdfData { context in
                context.beginPage()
                let ctx = UIGraphicsGetCurrentContext()!
                
                // Set up text attributes
                let titleAttributes = [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 24),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
                let headerAttributes = [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
                let textAttributes = [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
                
                // Draw title
                let title = "DELIVERY RECEIPT"
                let titleSize = title.size(withAttributes: titleAttributes)
                let titleX = (pageRect.width - titleSize.width) / 2
                title.draw(at: CGPoint(x: titleX, y: 40), withAttributes: titleAttributes)
                
                // Set up table drawing parameters
                var yPosition: CGFloat = 100
                let leftMargin: CGFloat = 50
                let labelWidth: CGFloat = 150  // Width for labels
                let valueWidth: CGFloat = 350  // Width for values
                let rowHeight: CGFloat = 25
                let padding: CGFloat = 5
                
                // Function to draw a table row with word wrap
                func drawTableRow(label: String, value: String, atY y: CGFloat) -> CGFloat {
                    let rect = CGRect(x: leftMargin, y: y, width: labelWidth + valueWidth, height: rowHeight)
                    ctx.stroke(rect)
                    
                    // Draw vertical line between columns
                    let midX = leftMargin + labelWidth
                    ctx.move(to: CGPoint(x: midX, y: y))
                    ctx.addLine(to: CGPoint(x: midX, y: y + rowHeight))
                    ctx.strokePath()
                    
                    // Draw label
                    let labelRect = CGRect(x: leftMargin + padding, y: y + padding, 
                                         width: labelWidth - padding * 2, height: rowHeight - padding * 2)
                    label.draw(in: labelRect, withAttributes: textAttributes)
                    
                    // Draw value with potential wrapping
                    let valueRect = CGRect(x: midX + padding, y: y + padding,
                                         width: valueWidth - padding * 2, height: rowHeight - padding * 2)
                    value.draw(in: valueRect, withAttributes: textAttributes)
                    
                    return y + rowHeight
                }
                
                // Draw Trip Information section
                "Trip Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                yPosition = drawTableRow(label: "Trip ID:", value: trip.id.uuidString, atY: yPosition)
                yPosition = drawTableRow(label: "Status:", value: trip.status.rawValue, atY: yPosition)
                yPosition = drawTableRow(label: "Vehicle:", value: trip.vehicleDetails.bodyType.rawValue, atY: yPosition)
                yPosition = drawTableRow(label: "License Plate:", value: trip.vehicleDetails.licensePlate, atY: yPosition)
                yPosition = drawTableRow(label: "Driver:", value: "Ravi", atY: yPosition)
                
                yPosition += 20
                
                // Draw Delivery Information section
                "Delivery Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                yPosition = drawTableRow(label: "Destination:", value: trip.destination, atY: yPosition)
                yPosition = drawTableRow(label: "Address:", value: trip.address, atY: yPosition)
                yPosition = drawTableRow(label: "Distance:", value: trip.distance, atY: yPosition)
                
                yPosition += 20
                
                // Draw Timing Information section
                "Timing Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                // Format dates properly
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                
                let startTimeStr = trip.startTime.map { dateFormatter.string(from: $0) } ?? "N/A"
                let endTimeStr = trip.endTime.map { dateFormatter.string(from: $0) } ?? "N/A"
                
                yPosition = drawTableRow(label: "Start Time:", value: startTimeStr, atY: yPosition)
                yPosition = drawTableRow(label: "End Time:", value: endTimeStr, atY: yPosition)
                
                yPosition += 20
                
                // Draw Cost Information section
                "Cost Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                let fuelCost = calculateFuelCost()
                let revenue = calculateRevenue()
                
                yPosition = drawTableRow(label: "Estimated Fuel Cost:", value: String(format: "$%.2f", fuelCost), atY: yPosition)
                yPosition = drawTableRow(label: "Total Revenue:", value: String(format: "$%.2f", revenue), atY: yPosition)
                
                yPosition += 20
                
                // Draw Notes section
                "Notes".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                let cargoType = trip.notes?.components(separatedBy: "Cargo Type:").last?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? "General Goods"
                yPosition = drawTableRow(label: "Cargo Type:", value: cargoType, atY: yPosition)
                yPosition = drawTableRow(label: "Estimated Distance:", value: trip.distance, atY: yPosition)
                
                yPosition += 40
                
                // Draw Signature section
                "Fleet Manager's Signature:".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 25
                
                // Draw signature box
                let signatureRect = CGRect(x: leftMargin, y: yPosition, width: 200, height: 60)
                ctx.stroke(signatureRect)
                
                yPosition += 80
                
                // Draw date with proper formatting
                let currentDate = Date()
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .none
                let dateString = "Date: \(dateFormatter.string(from: currentDate))"
                dateString.draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: textAttributes)
            }
            
            print("Receipt PDF generated")
            receiptData = pdfData
            showingDeliveryReceipt = true
            
        } catch {
            print("Error generating receipt: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func calculateFuelCost() -> Double {
        let numericDistance = trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            return distance * 0.5 // $0.5 per km
        }
        return 0.0
    }
    
    private func calculateRevenue() -> Double {
        return calculateFuelCost() * 1.5 // 50% margin
    }
    
    private func generateAndDownloadPDF() {
        isGeneratingPDF = true
        
        Task {
            do {
                // Create PDF content
                let pdfContent = generatePDFContent()
                
                // Get the documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "chat_history_\(trip.id.uuidString)_\(Date().formatted(.iso8601)).pdf"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Write PDF data to file
                try pdfContent.write(to: fileURL)
                
                // Show share sheet
                await MainActor.run {
                    isGeneratingPDF = false
                    pdfURL = fileURL
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isGeneratingPDF = false
                    errorMessage = "Failed to generate PDF: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func generatePDFContent() -> Data {
        // Create PDF content with better formatting
        var content = """
        TRIP CHAT HISTORY
        =================
        
        Trip Details:
        ------------
        Trip ID: \(trip.id.uuidString)
        From: \(trip.startingPoint)
        To: \(trip.destination)
        Status: Completed
        Vehicle: \(trip.vehicleDetails.make) \(trip.vehicleDetails.model)
        License Plate: \(trip.vehicleDetails.licensePlate)
        Date: \(Date().formatted())
        
        Chat History:
        ------------
        
        """
        
        // Sort messages by date
        let sortedMessages = chatViewModel.messages.sorted { $0.created_at < $1.created_at }
        
        // Add each message with proper formatting
        for message in sortedMessages {
            let sender = message.isFromFleetManager ? "Fleet Manager" : "Driver"
            let timestamp = message.created_at.formatted(date: .complete, time: .standard)
            content += "\n[\(timestamp)]\n\(sender): \(message.message_text)\n"
            content += "----------------------------------------\n"
        }
        
        if sortedMessages.isEmpty {
            content += "\nNo messages found for this trip.\n"
        }
        
        return Data(content.utf8)
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Completed"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusIcon: String {
        switch trip.status {
        case .inProgress:
            return "car.circle.fill"
        case .pending:
            return "clock.fill"
        case .delivered:
            return "checkmark.circle.fill"
        case .assigned:
            return "person.fill"
        }
    }
}

struct TripDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// ShareSheet view to handle sharing
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Add TripDeliveryReceiptViewer after ShareSheet
struct TripDeliveryReceiptViewer: View {
    @Environment(\.presentationMode) var presentationMode
    let data: Data
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            PDFKitView(data: data)
                .navigationTitle("Delivery Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [data])
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
            pdfView.autoScales = true
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .vertical
            pdfView.usePageViewController(true)
            pdfView.maxScaleFactor = 4.0
            pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// Add this extension to create PDF from HTML
extension String {
    func htmlAttributedString() -> NSAttributedString? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}

