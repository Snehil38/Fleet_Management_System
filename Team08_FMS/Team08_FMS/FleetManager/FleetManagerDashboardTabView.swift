//
//  FleetManagerDashboardView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI
import MapKit

struct FleetManagerDashboardTabView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @EnvironmentObject private var vehicleManager: VehicleManager
    @EnvironmentObject private var supabaseDataController: SupabaseDataController
    @State private var showingProfile = false
    @State private var showingAddTripSheet = false
    
    // Computed properties for counts and expenses
    private var availableVehiclesCount: Int {
        vehicleManager.vehicles.filter { $0.status == .available }.count
    }

    private var availableDriversCount: Int {
        dataManager.drivers.filter { $0.status == Status.available }.count
    }

    private var vehiclesUnderMaintenanceCount: Int {
        vehicleManager.vehicles.filter { $0.status == .underMaintenance }.count
    }

    private var totalMonthlySalaries: Double {
        dataManager.totalSalaryExpenses
    }

    private var totalExpenses: Double {
        totalMonthlySalaries  // Now total expenses is just the salary expenses
    }

    private var totalRevenue: Double {
        -totalExpenses  // Revenue is negative of expenses
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // Vehicles Stat
                        StatCard(
                            icon: "car.fill",
                            iconColor: .blue,
                            title: "Available Vehicles",
                            value: "\(availableVehiclesCount)"
                        )

                        // Drivers Stat
                        StatCard(
                            icon: "person.fill",
                            iconColor: .green,
                            title: "Available Drivers",
                            value: "\(availableDriversCount)"
                        )

                        // Maintenance Personnel Stat
                        StatCard(
                            icon: "wrench.fill",
                            iconColor: .orange,
                            title: "Under Maintenance",
                            value: "\(vehiclesUnderMaintenanceCount)"
                        )

                        // Active Trips Stat
                        StatCard(
                            icon: "arrow.triangle.turn.up.right.diamond.fill",
                            iconColor: .purple,
                            title: "Active Trips",
                            value: "0"
                        )
                    }
                    .padding(.horizontal)

                    // Add Trip Button
                    Button {
                        showingAddTripSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add New Trip")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                    }
                    .padding(.horizontal)

                    // Financial Summary
                    VStack(spacing: 16) {
                        // Total Expenses
                        FinancialCard(
                            title: "Total Expenses",
                            amount: "$\(String(format: "%.2f", totalExpenses))",
                            trend: .negative
                        )

                        // Monthly Salary Expenses
                        FinancialCard(
                            title: "Monthly Salary Expenses",
                            amount: "$\(String(format: "%.2f", totalMonthlySalaries))",
                            trend: .negative
                        )

                        // Total Revenue
                        FinancialCard(
                            title: "Total Revenue",
                            amount: "$\(String(format: "%.2f", totalRevenue))",
                            trend: .positive
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Fleet Manager")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationView {
                    FleetManagerProfileView()
                        .environmentObject(dataManager)
                }
            }
            .sheet(isPresented: $showingAddTripSheet) {
                NavigationView {
                    AddTripView(dismiss: { showingAddTripSheet = false })
                        .environmentObject(supabaseDataController)
                        .environmentObject(vehicleManager)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// Supporting Views
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                Spacer()
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
}

struct FinancialCard: View {
    let title: String
    let amount: String
    let trend: TrendType

    enum TrendType {
        case positive, negative
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(amount)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()

            Circle()
                .fill(trend == .positive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: trend == .positive ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(trend == .positive ? .green : .red)
                )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
}

struct AlertCard: View {
    let title: String
    let description: String
    let type: AlertType

    enum AlertType {
        case warning, error, success

        var color: Color {
            switch self {
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }

        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
}

// Enhanced trip creation view with real MapKit search
struct AddTripView: View {
    let dismiss: () -> Void
    @EnvironmentObject private var vehicleManager: VehicleManager
    @EnvironmentObject private var supabaseDataController: SupabaseDataController
    
    // Map and location state
    @State private var pickupLocation = ""
    @State private var dropoffLocation = ""
    @State private var pickupCoordinate: CLLocationCoordinate2D?
    @State private var dropoffCoordinate: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 25)
    )
    @State private var routePolyline: MKPolyline?
    
    // Search state
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var activeTextField: LocationField? = nil
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: SearchCompleterDelegate? = nil
    
    // Trip details state
    @State private var selectedVehicle: Vehicle?
    @State private var cargoType = "General Goods"
    @State private var startDate = Date()
    @State private var deliveryDate = Date().addingTimeInterval(86400)
    @State private var distance: Double = 0.0
    @State private var fuelCost: Double = 0.0
    @State private var tripCost: Double = 0.0
    @State private var isCalculating = false
    @State private var selectedTab = 0
    @State private var notes: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let cargoTypes = ["General Goods", "Perishable", "Hazardous", "Heavy Machinery", "Liquids", "Livestock"]
    
    enum LocationField {
        case pickup, dropoff
    }
    
    var isFormValid: Bool {
        !pickupLocation.isEmpty && !dropoffLocation.isEmpty && pickupLocation != dropoffLocation && selectedVehicle != nil
    }
    
    var availableVehicles: [Vehicle] {
        vehicleManager.vehicles.filter { $0.status == .available }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Map View - Full width at top
                    MapView(
                        pickupCoordinate: pickupCoordinate,
                        dropoffCoordinate: dropoffCoordinate,
                        routePolyline: routePolyline,
                        region: $region
                    )
                    .frame(height: 250)
                    
                    // Content Section
                    VStack(spacing: 16) {
                        // Primary Information Group
                        Group {
                            // Route Information Card
                            CardView(title: "ROUTE INFORMATION") {
                                VStack(spacing: 16) {
                                    // Pickup Location
                                    LocationInputField(
                                        icon: "mappin.circle.fill",
                                        iconColor: .blue,
                                        placeholder: "Enter pickup location",
                                        text: $pickupLocation,
                                        onClear: {
                                            pickupLocation = ""
                                            pickupCoordinate = nil
                                            updateMapRegion()
                                        },
                                        onChange: { newValue in
                                            if newValue.count > 2 {
                                                searchCompleter.queryFragment = newValue + ", India"
                                                activeTextField = .pickup
                                            } else {
                                                searchResults = []
                                            }
                                        }
                                    )
                                    
                                    // Dropoff Location
                                    LocationInputField(
                                        icon: "mappin.and.ellipse",
                                        iconColor: .red,
                                        placeholder: "Enter dropoff location",
                                        text: $dropoffLocation,
                                        onClear: {
                                            dropoffLocation = ""
                                            dropoffCoordinate = nil
                                            updateMapRegion()
                                        },
                                        onChange: { newValue in
                                            if newValue.count > 2 {
                                                searchCompleter.queryFragment = newValue + ", India"
                                                activeTextField = .dropoff
                                            } else {
                                                searchResults = []
                                            }
                                        }
                                    )
                                }
                            }
                            
                            // Search Results if any
                            if !searchResults.isEmpty {
                                LocationSearchResults(results: searchResults) { result in
                                    if activeTextField == .pickup {
                                        searchForLocation(result.title, isPickup: true)
                                    } else {
                                        searchForLocation(result.title, isPickup: false)
                                    }
                                }
                            }
                        }
                        
                        // Secondary Information Group
                        Group {
                            // Vehicle Selection Card
                            CardView(title: "VEHICLE SELECTION") {
                                Menu {
                                    ForEach(availableVehicles) { vehicle in
                                        Button("\(vehicle.name) (\(vehicle.licensePlate))") {
                                            selectedVehicle = vehicle
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedVehicle == nil ? "Select Vehicle" : "\(selectedVehicle!.name) (\(selectedVehicle!.licensePlate))")
                                            .foregroundColor(selectedVehicle == nil ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Cargo Details Card
                            CardView(title: "CARGO DETAILS") {
                                Menu {
                                    ForEach(cargoTypes, id: \.self) { type in
                                        Button(type) {
                                            cargoType = type
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(cargoType)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Schedule Card
                            CardView(title: "SCHEDULE") {
                                VStack(spacing: 16) {
                                    // Start Date
                                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                        .onChange(of: startDate) { newDate in
                                            // If we have a calculated route, update delivery date based on new start date
                                            if distance > 0 {
                                                let estimatedHours = distance / 40.0
                                                let timeInterval = estimatedHours * 3600
                                                deliveryDate = newDate.addingTimeInterval(timeInterval)
                                            }
                                        }
                                    
                                    // Only show delivery date if route is calculated
                                    if distance > 0 {
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Estimated Delivery")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.blue)
                                                Text(deliveryDate, style: .date)
                                                    .font(.headline)
                                            }
                                            
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text(deliveryDate, style: .time)
                                                    .font(.headline)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            // Notes Card
                            CardView(title: "NOTES") {
                                TextEditor(text: $notes)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            
                            // Trip Estimates Card (if available)
                            if distance > 0 {
                                CardView(title: "TRIP ESTIMATES") {
                                    VStack(spacing: 16) {
                                        // Distance and Time Row
                                        HStack(spacing: 20) {
                                            EstimateItem(
                                                icon: "arrow.left.and.right",
                                                title: "Total Distance",
                                                value: String(format: "%.1f km", distance)
                                            )
                                            
                                            Divider()
                                            
                                            EstimateItem(
                                                icon: "clock.fill",
                                                title: "Est. Travel Time",
                                                value: String(format: "%.1f hours", distance / 40.0)
                                            )
                                            .onAppear {
                                                let hours = distance / 40.0
                                                let timeInterval = hours * 3600
                                                deliveryDate = startDate.addingTimeInterval(timeInterval)
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // Fuel Cost Row
                                        EstimateItem(
                                            icon: "fuelpump.fill",
                                            title: "Est. Fuel Cost",
                                            value: String(format: "$%.2f", fuelCost),
                                            valueColor: .blue
                                        )
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        // Bottom spacing to prevent button overlap
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Fixed Bottom Button
            VStack(spacing: 0) {
                Button(action: distance > 0 ? saveTrip : calculateRoute) {
                    HStack {
                        if isCalculating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(distance > 0 ? "Create Trip" : "Calculate Route")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(!isFormValid || isCalculating)
                .padding(16)
                .background(
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
                )
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("Add New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Trip Creation"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            setupSearchCompleter()
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = .address
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // Center of India
            span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
        )
        
        // Set up the delegate
        let delegate = SearchCompleterDelegate { results in
            self.searchResults = results
        }
        searchCompleter.delegate = delegate
        
        // Store the delegate to prevent it from being deallocated
        searchCompleterDelegate = delegate
    }
    
    private func hideSearchResults() {
        searchResults = []
        activeTextField = nil
    }
    
    private func searchForLocation(_ query: String, isPickup: Bool) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // Center of India
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first, error == nil else {
                return
            }
            
            if isPickup {
                self.pickupLocation = mapItem.name ?? query
                self.pickupCoordinate = mapItem.placemark.coordinate
            } else {
                self.dropoffLocation = mapItem.name ?? query
                self.dropoffCoordinate = mapItem.placemark.coordinate
            }
            
            self.hideSearchResults()
            self.updateMapRegion()
        }
    }
    
    private func updateMapRegion() {
        // If we have both coordinates, center the map to show both
        if let pickup = pickupCoordinate, let dropoff = dropoffCoordinate {
            let centerLat = (pickup.latitude + dropoff.latitude) / 2
            let centerLon = (pickup.longitude + dropoff.longitude) / 2
            
            // Calculate span to fit both points with padding
            let latDelta = abs(pickup.latitude - dropoff.latitude) * 1.8 // Increased padding
            let lonDelta = abs(pickup.longitude - dropoff.longitude) * 1.8 // Increased padding
            
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.05), longitudeDelta: max(lonDelta, 0.05))
            )
        } else if let pickup = pickupCoordinate {
            region = MKCoordinateRegion(
                center: pickup,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5) // Increased zoom level
            )
        } else if let dropoff = dropoffCoordinate {
            region = MKCoordinateRegion(
                center: dropoff,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5) // Increased zoom level
            )
        }
    }
    
    private func calculateRoute() {
        guard let pickup = pickupCoordinate, let dropoff = dropoffCoordinate else {
            return
        }
        
        isCalculating = true
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: pickup))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dropoff))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            self.isCalculating = false
            
            guard let route = response?.routes.first, error == nil else {
                // Fallback to straight-line distance if route calculation fails
                self.calculateStraightLineDistance(from: pickup, to: dropoff)
                return
            }
            
            // Get the route polyline
            self.routePolyline = route.polyline
            
            // Get distance in kilometers
            self.distance = route.distance / 1000
            
            // Calculate costs with $5 per km
            let fuelRatio = 0.2 // 20% of cost is fuel
            let costPerKm = 5.0 // $5 per km as requested
            
            self.tripCost = self.distance * costPerKm
            self.fuelCost = self.tripCost * fuelRatio
            
            // Calculate estimated travel time and update delivery date
            let estimatedHours = self.distance / 40.0 // Assuming average speed of 40 km/h
            let timeInterval = estimatedHours * 3600 // Convert hours to seconds
            self.deliveryDate = self.startDate.addingTimeInterval(timeInterval)
            
            self.updateMapRegion()
        }
    }
    
    private func calculateStraightLineDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let locationA = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let locationB = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        // Get distance in kilometers
        distance = locationA.distance(from: locationB) / 1000
        
        // Calculate costs with $5 per km
        let fuelRatio = 0.2 // 20% of cost is fuel
        let costPerKm = 5.0 // $5 per km as requested
        
        tripCost = distance * costPerKm
        fuelCost = tripCost * fuelRatio
        
        // Calculate estimated travel time and update delivery date
        let estimatedHours = distance / 40.0 // Assuming average speed of 40 km/h
        let timeInterval = estimatedHours * 3600 // Convert hours to seconds
        deliveryDate = startDate.addingTimeInterval(timeInterval)
        
        // Create a simple polyline between points for visualization
        let points = [source, destination]
        routePolyline = MKPolyline(coordinates: points, count: points.count)
    }
    
    private func saveTrip() {
        Task {
            guard let vehicle = selectedVehicle else { return }
            
            let tripName = "TRP-\(UUID().uuidString.prefix(8))"
            
            do {
                let success = try await supabaseDataController.createTrip(
                    name: pickupLocation,
                    destination: dropoffLocation,
                    vehicleId: vehicle.id,
                    driverId: nil,
                    startTime: startDate,
                    endTime: deliveryDate,
                    startLat: pickupCoordinate?.latitude,
                    startLong: pickupCoordinate?.longitude,
                    endLat: dropoffCoordinate?.latitude,
                    endLong: dropoffCoordinate?.longitude,
                    notes: "Cargo Type: \(cargoType)\nEstimated Distance: \(String(format: "%.1f", distance)) km\nEstimated Fuel Cost: $\(String(format: "%.2f", fuelCost))\n\(notes)"
                )
                
                if success {
                    dismiss()
                } else {
                    alertMessage = "Failed to create trip. Please try again."
                    showingAlert = true
                }
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

// Search completer delegate to handle MapKit search results
class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onResultsUpdated: ([MKLocalSearchCompletion]) -> Void
    
    init(onResultsUpdated: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onResultsUpdated = onResultsUpdated
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResultsUpdated(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// Location search results component
struct LocationSearchResults: View {
    let results: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(results, id: \.self) { result in
                    Button {
                        onSelect(result)
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.headline)
                            VStack(alignment: .leading) {
                                Text(result.title)
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .frame(height: min(CGFloat(results.count * 60), 240))
    }
}

// MapView component to display route
struct MapView: UIViewRepresentable {
    let pickupCoordinate: CLLocationCoordinate2D?
    let dropoffCoordinate: CLLocationCoordinate2D?
    let routePolyline: MKPolyline?
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.region = region
        
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add pickup annotation
        if let coordinate = pickupCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Pickup"
            mapView.addAnnotation(annotation)
        }
        
        // Add dropoff annotation
        if let coordinate = dropoffCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Dropoff"
            mapView.addAnnotation(annotation)
        }
        
        // Add route polyline if available
        if let polyline = routePolyline {
            mapView.addOverlay(polyline)
            
            // Adjust the visible region to show the entire route
            if pickupCoordinate != nil && dropoffCoordinate != nil {
                mapView.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                    animated: true
                )
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "LocationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Set color based on title
            if annotation.title == "Pickup" {
                annotationView?.markerTintColor = .green
            } else {
                annotationView?.markerTintColor = .red
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Helper Views for better organization
struct CardView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            content
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
    }
}

struct LocationInputField: View {
    let icon: String
    let iconColor: Color
    let placeholder: String
    @Binding var text: String
    let onClear: () -> Void
    let onChange: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 24))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text, perform: onChange)
            
            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct EstimateItem: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
                .foregroundColor(valueColor)
        }
    }
}
