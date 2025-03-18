import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @StateObject private var dataController = SupabaseDataController.shared
    @State private var isAuthenticated = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Text("TrackNGo")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.pink.opacity(0.5))
                    .padding(.top, 20)

                Image("image")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .padding(.bottom, 20)

                Text("Welcome Back!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)

                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(radius: 1)
                    .padding(.horizontal, 20)

                SecureField("Password", text: $password)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(25)
                    .shadow(radius: 1)
                    .padding(.horizontal, 20)

                Button(action: {
                    SupabaseDataController.shared.signIn(email: email, password: password) { result in
                        switch result {
                        case .success:
                            isAuthenticated = true
                            navigateToDashboard()
                        case .failure(let error):
                            print("❌ Sign-in failed: \(error.localizedDescription)")
                        }
                    }
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .navigationDestination(for: String.self) { role in
                switch role {
                case "fleet_manager":
                    FleetManagerHomeScreen()
                case "driver":
                    DriverHomeScreen()
                case "maintenance_personnel":
                    MaintenancePersonnelHomeScreen()
                default:
                    Text("Unknown Role")
                }
            }
        }
    }

    private func navigateToDashboard() {
        if let role = dataController.userRole {
            navigationPath = NavigationPath([role]) // Replaces the navigation stack
        }
    }
}

#Preview {
    LoginView()
}
