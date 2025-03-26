import SwiftUI

struct MaintenancePersonnelUpcomingServicesView: View {
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @State private var searchText = ""
    @State private var selectedServiceType: ServiceType?
    @State private var selectedSchedule: MaintenancePersonnelRoutineSchedule?
    @State private var showingDetail = false
    
    var filteredSchedules: [MaintenancePersonnelRoutineSchedule] {
        var schedules = dataStore.routineSchedules
        
        if let serviceType = selectedServiceType {
            schedules = schedules.filter { $0.serviceType == serviceType }
        }
        
        if !searchText.isEmpty {
            schedules = schedules.filter {
                $0.vehicleName.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return schedules.sorted { $0.nextServiceDate < $1.nextServiceDate }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search schedules...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ServiceType.allCases, id: \.self) { type in
                            ServiceTypeFilterButton(
                                type: type,
                                isSelected: selectedServiceType == type,
                                action: {
                                    withAnimation {
                                        selectedServiceType = selectedServiceType == type ? nil : type
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            if filteredSchedules.isEmpty {
                ServicesEmptyStateView(
                    icon: "calendar",
                    title: "No Upcoming Services",
                    message: "There are no upcoming service schedules to display."
                )
            } else {
                List {
                    ForEach(filteredSchedules) { schedule in
                        UpcomingServiceRow(schedule: schedule)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSchedule = schedule
                                showingDetail = true
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let schedule = selectedSchedule {
                NavigationView {
                    UpcomingServiceDetailView(schedule: schedule)
                        .navigationTitle("Service Schedule Details")
                        .navigationBarItems(trailing: Button("Done") {
                            showingDetail = false
                        })
                }
            }
        }
    }
}

struct UpcomingServiceRow: View {
    let schedule: MaintenancePersonnelRoutineSchedule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.vehicleName)
                    .font(.headline)
                Spacer()
                ServiceTypeBadge(type: schedule.serviceType)
            }
            
            Text(schedule.notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("Next Service", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(schedule.nextServiceDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            if schedule.nextServiceDate < Date().addingTimeInterval(86400 * 7) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Due within 7 days")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct UpcomingServiceDetailView: View {
    let schedule: MaintenancePersonnelRoutineSchedule
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Vehicle Info Card
                MaintenanceVehicleScheduleInfoCard(schedule: schedule)
                
                // Service Schedule Card
                ServiceScheduleCard(schedule: schedule)
            }
            .padding(.vertical)
        }
    }
}

struct MaintenanceVehicleScheduleInfoCard: View {
    let schedule: MaintenancePersonnelRoutineSchedule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Information")
                .font(.headline)
            
            Divider()
            
            InfoRow(title: "Vehicle", value: schedule.vehicleName, icon: "car.fill")
            InfoRow(title: "Service Type", value: schedule.serviceType.rawValue, icon: "wrench.fill")
            InfoRow(title: "Interval", value: "\(schedule.interval) days", icon: "clock.fill")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct ServiceScheduleCard: View {
    let schedule: MaintenancePersonnelRoutineSchedule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Schedule")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                ScheduleRow(
                    title: "Last Service",
                    date: schedule.lastServiceDate,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                ScheduleRow(
                    title: "Next Service",
                    date: schedule.nextServiceDate,
                    icon: "calendar",
                    color: .blue
                )
                
                if !schedule.notes.isEmpty {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 4)
                    
                    Text(schedule.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct ScheduleRow: View {
    let title: String
    let date: Date
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if title == "Next Service" && date < Date().addingTimeInterval(86400 * 7) {
                Text("Due Soon")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    MaintenancePersonnelUpcomingServicesView(dataStore: MaintenancePersonnelDataStore())
} 
