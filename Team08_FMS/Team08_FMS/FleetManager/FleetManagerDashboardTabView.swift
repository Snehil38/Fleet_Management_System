//
//  FleetManagerDashboardView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI
import MapKit
import Combine

struct FleetManagerDashboardTabView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @EnvironmentObject private var vehicleManager: VehicleManager
    @EnvironmentObject private var supabaseDataController: SupabaseDataController
    @StateObject private var tripController = TripDataController.shared
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

    private var activeTripsCount: Int {
        // Only count trips that are in progress
        tripController.getAllTrips().filter { $0.status == .inProgress }.count
    }

    private var totalMonthlySalaries: Double {
        dataManager.totalSalaryExpenses
    }

    private var totalFuelCost: Double {
        // Calculate total fuel cost from all trips
        tripController.getAllTrips().reduce(0) { total, trip in
            // Extract numeric value from distance string
            let numericDistance = trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            
            if let distance = Double(numericDistance) {
                // Calculate fuel cost ($0.5 per km)
                return total + (distance * 0.5)
            }
            return total
        }
    }

    private var totalTripRevenue: Double {
        // Calculate total revenue from all trips
        tripController.getAllTrips().reduce(0) { total, trip in
            // Extract numeric value from distance string
            let numericDistance = trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            
            if let distance = Double(numericDistance) {
                // Total Revenue = Fuel Cost + ($0.25 × Distance) + $50
                let fuelCost = distance * 0.5
                let distanceRevenue = distance * 0.25
                return total + (fuelCost + distanceRevenue + 50.0)
            }
            return total
        }
    }

    private var totalExpenses: Double {
        totalMonthlySalaries + totalFuelCost
    }

    private var totalRevenue: Double {
        totalTripRevenue - totalExpenses
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
                            value: "\(activeTripsCount)"
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

// Extract route information into a separate view
struct RouteInformationView: View {
    @Binding var pickupLocation: String
    @Binding var dropoffLocation: String
    let onPickupClear: () -> Void
    let onDropoffClear: () -> Void
    let onPickupChange: (String) -> Void
    let onDropoffChange: (String) -> Void
    let onLocationRequest: () -> Void
    
    var body: some View {
        CardView(title: "ROUTE INFORMATION", systemImage: "map") {
            VStack(spacing: 16) {
                // Pickup Location
                LocationInputField(
                    icon: "mappin.circle.fill",
                    iconColor: Color(red: 0.2, green: 0.5, blue: 1.0),
                    placeholder: "Enter pickup location (address, landmark, etc.)",
                    text: $pickupLocation,
                    onClear: onPickupClear,
                    onChange: onPickupChange,
                    showLocationButton: true,
                    onLocationRequest: onLocationRequest
                )
                
                // Dropoff Location
                LocationInputField(
                    icon: "mappin.and.ellipse",
                    iconColor: Color(red: 0.9, green: 0.3, blue: 0.3),
                    placeholder: "Enter dropoff location (address, landmark, etc.)",
                    text: $dropoffLocation,
                    onClear: onDropoffClear,
                    onChange: onDropoffChange
                )
            }
        }
    }
}

// Extract vehicle selection into a separate view
struct VehicleSelectionView: View {
    @Binding var selectedVehicle: Vehicle?
    let availableVehicles: [Vehicle]
    
    var body: some View {
        CardView(title: "VEHICLE SELECTION", systemImage: "car.fill") {
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
    }
}

// Update AddTripView to use the new components
struct AddTripView: View {
    // Make initializer public
    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }
    
    let dismiss: () -> Void
    @EnvironmentObject private var vehicleManager: VehicleManager
    @EnvironmentObject private var supabaseDataController: SupabaseDataController
    
    // Location Manager for current location
    @StateObject private var locationManager = LocationManager()
    @State private var isRequestingLocation = false
    @State private var cancellables = Set<AnyCancellable>()
    
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
    
    // Break down complex expressions
    private var isLocationValid: Bool {
        !pickupLocation.isEmpty && !dropoffLocation.isEmpty && pickupLocation != dropoffLocation
    }
    
    private var isVehicleSelected: Bool {
        selectedVehicle != nil
    }
    
    var isFormValid: Bool {
        isLocationValid && isVehicleSelected
    }
    
    var availableVehicles: [Vehicle] {
        vehicleManager.vehicles.filter { $0.status == .available }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Map View
                    MapView(
                        pickupCoordinate: pickupCoordinate,
                        dropoffCoordinate: dropoffCoordinate,
                        routePolyline: routePolyline,
                        region: $region
                    )
                    .frame(height: 250)
                    
                    // Content Section
                    VStack(spacing: 16) {
                        // Route Information
                        RouteInformationView(
                            pickupLocation: $pickupLocation,
                            dropoffLocation: $dropoffLocation,
                            onPickupClear: {
                                pickupLocation = ""
                                pickupCoordinate = nil
                                updateMapRegion()
                            },
                            onDropoffClear: {
                                dropoffLocation = ""
                                dropoffCoordinate = nil
                                updateMapRegion()
                            },
                            onPickupChange: { newValue in
                                if newValue.count > 2 {
                                    searchCompleter.queryFragment = newValue
                                    activeTextField = .pickup
                                } else {
                                    searchResults = []
                                }
                            },
                            onDropoffChange: { newValue in
                                if newValue.count > 2 {
                                    searchCompleter.queryFragment = newValue
                                    activeTextField = .dropoff
                                } else {
                                    searchResults = []
                                }
                            },
                            onLocationRequest: {
                                isRequestingLocation = true
                                locationManager.requestLocation()
                            }
                        )
                        
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
                        
                        // Vehicle Selection
                        VehicleSelectionView(
                            selectedVehicle: $selectedVehicle,
                            availableVehicles: availableVehicles
                        )
                        
                        // Cargo Details Card
                        CardView(title: "CARGO DETAILS", systemImage: "shippingbox.fill") {
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
                        CardView(title: "SCHEDULE", systemImage: "calendar") {
                            VStack(spacing: 16) {
                                // Start Date
                                DatePicker("Start Date", 
                                    selection: $startDate,
                                    in: Date()..., // This sets the minimum date to today
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .onChange(of: startDate) { newDate, _ in
                                    if distance > 0 {
                                        let estimatedHours = distance / 40.0
                                        let timeInterval = estimatedHours * 3600
                                        deliveryDate = newDate.addingTimeInterval(timeInterval)
                                    }
                                }
                                .tint(Color(red: 0.2, green: 0.5, blue: 1.0))
                                
                                if distance > 0 {
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Estimated Delivery")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
                                            Text(deliveryDate, style: .date)
                                                .font(.headline)
                                        }
                                        
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
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
                        
                        // Trip Estimates Card (if available)
                        if distance > 0 {
                            CardView(title: "TRIP ESTIMATES", systemImage: "chart.bar.fill") {
                                VStack(spacing: 16) {
                                    // Distance and Time Row
                                    HStack(spacing: 20) {
                                        EstimateItem(
                                            icon: "arrow.left.and.right",
                                            title: "Total Distance",
                                            value: String(format: "%.1f km", distance),
                                            valueColor: Color(red: 0.2, green: 0.5, blue: 1.0)
                                        )
                                        
                                        Divider()
                                        
                                        EstimateItem(
                                            icon: "clock.fill",
                                            title: "Est. Travel Time",
                                            value: String(format: "%.1f hours", distance / 40.0),
                                            valueColor: Color(red: 0.2, green: 0.5, blue: 1.0)
                                        )
                                    }
                                    
                                    Divider()
                                    
                                    // Fuel Cost Row
                                    EstimateItem(
                                        icon: "fuelpump.fill",
                                        title: "Est. Fuel Cost",
                                        value: String(format: "$%.2f", fuelCost),
                                        valueColor: Color(red: 0.2, green: 0.5, blue: 1.0)
                                    )
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Remove the debug log view display
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
            
            // Observe location updates
            locationManager.objectWillChange.sink { [weak locationManager] _ in
                if let location = locationManager?.location {
                    let geocoder = CLGeocoder()
                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                        if let placemark = placemarks?.first {
                            let address = [
                                placemark.name,
                                placemark.thoroughfare,
                                placemark.locality,
                                placemark.administrativeArea
                            ].compactMap { $0 }.joined(separator: ", ")
                            
                            if isRequestingLocation {
                                pickupLocation = address
                                pickupCoordinate = location.coordinate
                                updateMapRegion()
                                isRequestingLocation = false
                            }
                        }
                    }
                }
            }.store(in: &cancellables)
        }
    }
    
    private func setupSearchCompleter() {
        // Enable all result types to get the most detailed location results
        searchCompleter.resultTypes = [.pointOfInterest, .address, .query]
        
        // Set a smaller region for more precise results
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // Center of India
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10) // Smaller span for more detailed results
        )
        
        // Set up the delegate
        let delegate = SearchCompleterDelegate { results in
            // Limit to top 10 results for better performance
            self.searchResults = Array(results.prefix(10))
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
        
        // Include more result types for detailed locations
        searchRequest.resultTypes = [.pointOfInterest, .address]
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response, error == nil else {
                return
            }
            
            // Get the first result if available
            if let mapItem = response.mapItems.first {
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
    }
    
    private func updateMapRegion() {
        // If we have both coordinates, center the map to show both
        if let pickup = pickupCoordinate, let dropoff = dropoffCoordinate {
            let centerLat = (pickup.latitude + dropoff.latitude) / 2
            let centerLon = (pickup.longitude + dropoff.longitude) / 2
            
            // Calculate span to fit both points with padding
            let latDelta = abs(pickup.latitude - dropoff.latitude) * 1.5 // Reduced padding for more detail
            let lonDelta = abs(pickup.longitude - dropoff.longitude) * 1.5 // Reduced padding for more detail
            
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.02), longitudeDelta: max(lonDelta, 0.02))
            )
        } else if let pickup = pickupCoordinate {
            region = MKCoordinateRegion(
                center: pickup,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02) // More detailed zoom level
            )
        } else if let dropoff = dropoffCoordinate {
            region = MKCoordinateRegion(
                center: dropoff,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02) // More detailed zoom level
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
            
            let estimatedHours = distance / 40.0
            
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
                    notes: "Cargo Type: \(cargoType)\nEstimated Distance: \(String(format: "%.1f", distance)) km\nEstimated Fuel Cost: $\(String(format: "%.2f", fuelCost))",
                    distance: distance,
                    time: estimatedHours,
                    cost: fuelCost
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
                        HStack(alignment: .top, spacing: 12) {
                            // Map pin icon with different colors for different types of locations
                            Image(systemName: iconForResult(result))
                                .foregroundColor(colorForResult(result))
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                
                                // Display the type of location
                                if let locationType = getLocationType(result) {
                                    Text(locationType)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
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
        .frame(height: min(CGFloat(results.count * 70), 280))
    }
    
    // Helper function to determine icon based on result type
    private func iconForResult(_ result: MKLocalSearchCompletion) -> String {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return "fork.knife"
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return "bed.double.fill"
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return "cross.fill"
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return "book.fill"
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return "leaf.fill"
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return "bag.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    // Helper function to determine color based on result type
    private func colorForResult(_ result: MKLocalSearchCompletion) -> Color {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return .orange
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return .blue
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return .red
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return .green
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return .green
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return .purple
        } else {
            return .red
        }
    }
    
    // Helper function to get location type
    private func getLocationType(_ result: MKLocalSearchCompletion) -> String? {
        let subtitle = result.subtitle.lowercased()
        
        if subtitle.contains("restaurant") || subtitle.contains("café") || subtitle.contains("cafe") {
            return "Restaurant"
        } else if subtitle.contains("hotel") || subtitle.contains("resort") {
            return "Hotel"
        } else if subtitle.contains("hospital") || subtitle.contains("clinic") {
            return "Healthcare"
        } else if subtitle.contains("school") || subtitle.contains("college") || subtitle.contains("university") {
            return "Education"
        } else if subtitle.contains("park") || subtitle.contains("garden") {
            return "Park"
        } else if subtitle.contains("mall") || subtitle.contains("shop") || subtitle.contains("store") {
            return "Shopping"
        } else if subtitle.contains("airport") || subtitle.contains("station") {
            return "Transport"
        } else if subtitle.contains("street") || subtitle.contains("road") {
            return "Street"
        } else if subtitle.contains("city") || subtitle.contains("town") {
            return "City"
        } else if subtitle.contains("landmark") || subtitle.contains("monument") {
            return "Landmark"
        } else {
            return nil
        }
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
        
        // Enhanced map with maximum detail
        mapView.mapType = .mutedStandard // Using muted standard for a cleaner look with all details
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.showsPointsOfInterest = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
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
    let systemImage: String
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            
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
    var showLocationButton: Bool = false
    var onLocationRequest: (() -> Void)? = nil
    
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
            
            if showLocationButton {
                Button(action: {
                    onLocationRequest?()
                }) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
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

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var error: Error?
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var debugLog: String = ""
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        addDebugLog("LocationManager initialized")
        checkLocationAuthorization()
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog += "[\(timestamp)] \(message)\n"
        print("Location Debug: [\(timestamp)] \(message)")
    }
    
    func requestLocation() {
        addDebugLog("Location request initiated")
        let status = locationManager.authorizationStatus
        addDebugLog("Current authorization status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            addDebugLog("Authorization status not determined, requesting authorization")
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            addDebugLog("Location access is restricted")
            self.error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access is restricted. Please check your device settings."]
            )
        case .denied:
            addDebugLog("Location access is denied")
            self.error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access is denied. Please enable location services in Settings."]
            )
        case .authorizedWhenInUse, .authorizedAlways:
            addDebugLog("Location authorized, requesting location update")
            locationManager.requestLocation()
        @unknown default:
            addDebugLog("Unknown authorization status: \(status.rawValue)")
            self.error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown location authorization status."]
            )
        }
    }
    
    private func checkLocationAuthorization() {
        let status = locationManager.authorizationStatus
        self.authorizationStatus = status
        addDebugLog("Checking location authorization: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            addDebugLog("Authorization not determined, requesting authorization")
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            let message = status == .denied ?
                "Location access is denied. Please enable location services in Settings." :
                "Location access is restricted. Please check your device settings."
            addDebugLog("Location access restricted/denied: \(message)")
            error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        case .authorizedWhenInUse, .authorizedAlways:
            addDebugLog("Location access authorized")
            break
        @unknown default:
            addDebugLog("Unknown authorization status encountered")
            error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown location authorization status."]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            addDebugLog("Location update received but no location data")
            return
        }
        addDebugLog("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        self.location = location
        self.error = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        addDebugLog("Location manager failed with error: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                addDebugLog("Location access denied by user")
                self.error = NSError(
                    domain: "LocationError",
                    code: Int(CLError.denied.rawValue),
                    userInfo: [NSLocalizedDescriptionKey: "Location access denied. Please enable location services in Settings."]
                )
            case .locationUnknown:
                addDebugLog("Location unknown error")
                self.error = NSError(
                    domain: "LocationError",
                    code: Int(CLError.locationUnknown.rawValue),
                    userInfo: [NSLocalizedDescriptionKey: "Unable to determine location. Please try again."]
                )
            default:
                addDebugLog("Other location error: \(clError.code.rawValue)")
                self.error = error
            }
        } else {
            addDebugLog("Non-CLError received: \(error)")
            self.error = error
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        addDebugLog("Authorization status changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            addDebugLog("Location authorized, requesting location")
            locationManager.requestLocation()
        case .denied:
            addDebugLog("Location access denied")
            self.error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied. Please enable location services in Settings."]
            )
        case .restricted:
            addDebugLog("Location access restricted")
            self.error = NSError(
                domain: "LocationError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access is restricted. Please check your device settings."]
            )
        default:
            addDebugLog("Other authorization status: \(status.rawValue)")
            break
        }
    }
}
