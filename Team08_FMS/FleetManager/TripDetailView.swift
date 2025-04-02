struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @StateObject private var tripController = TripDataController.shared
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    var trip: Trip
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    @State private var loading = false
    
    // Editing state variables
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    
    // Delivery receipt state
    @State private var showingDeliveryReceipt = false
    @State private var pdfData: Data? = nil
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    @State private var showingSignatureSheet = false
    @State private var fleetManagerSignature: Data? = nil
    
    // Location search state
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var activeTextField: LocationField? = nil
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: FleetTripsSearchCompleterDelegate? = nil
    @State private var destinationSelected = false
    @State private var addressSelected = false
    
    // Touched states
    @State private var destinationEdited = false
    @State private var addressEdited = false
    @State private var notesEdited = false
    
    // Save operation state
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map View
                MapView(
                    pickupCoordinate: trip.sourceCoordinate,
                    dropoffCoordinate: trip.destinationCoordinate,
                    region: .constant(MKCoordinateRegion(
                        center: trip.destinationCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                )
                .frame(height: 200)
                .cornerRadius(12)
                
                // Trip Details
                Form {
                    Section(header: Text("TRIP INFORMATION")) {
                        FleetTripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                        if let pickup = trip.pickup {
                            FleetTripDetailRow(icon: "location.fill", title: "Pickup", value: pickup)
                        }
                        if !trip.distance.isEmpty {
                            FleetTripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                        }
                        if !trip.eta.isEmpty {
                            FleetTripDetailRow(icon: "clock.fill", title: "ETA", value: trip.eta)
                        }
                        if let notes = trip.notes {
                            FleetTripDetailRow(icon: "note.text", title: "Notes", value: notes)
                        }
                    }
                    
                    Section(header: Text("STATUS INFORMATION")) {
                        FleetTripDetailRow(icon: "info.circle.fill", title: "Status", value: trip.status.rawValue.capitalized)
                        if let startTime = trip.startTime {
                            FleetTripDetailRow(icon: "clock.fill", title: "Start Time", value: dateFormatter.string(from: startTime))
                        }
                        if let endTime = trip.endTime {
                            FleetTripDetailRow(icon: "clock.fill", title: "End Time", value: dateFormatter.string(from: endTime))
                        }
                    }
                    
                    Section(header: Text("VEHICLE INFORMATION")) {
                        FleetTripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                        FleetTripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if trip.status == .pending {
                        Button(action: {
                            showingAssignSheet = true
                        }) {
                            Label("Assign Driver", systemImage: "person.fill.badge.plus")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAssignSheet) {
            AssignDriverView(trip: trip)
        }
        .alert("Delete Trip", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteTrip()
                }
            }
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
    }
    
    private func deleteTrip() async {
        do {
            try await tripController.deleteTrip(tripId: trip.id)
            dismiss()
        } catch {
            print("Error deleting trip: \(error)")
        }
    }
} 