import SwiftUI

struct RoleSelectionView: View {
    @State private var selectedRole: String? = nil
    @State private var navigateToLogin = false
    let roles = ["Fleet Manager", "Driver", "Maintenance Personnel"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("TrackNGo")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.pink.opacity(0.5))
                    .padding(.top, 20)
                
                Image("image")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.bottom, 20)
                
                Text("Select Your Role")
                    .font(.headline)
                
                VStack(spacing: 10) {
                    ForEach(roles, id: \ .self) { role in
                        Button(action: {
                            selectedRole = role
                            UserDefaults.standard.set(role, forKey: "selectedRole")
                            navigateToLogin = true
                        }) {
                            Text(role)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding()
            .navigationDestination(isPresented: $navigateToLogin) {
                NavigationStack {
                    LoginView(selectedRole: selectedRole ?? "")
                }
            }
        }
    }
}

struct LoginView: View {
    var selectedRole: String
    @State private var email: String = ""
    @State private var password: String = ""
    @StateObject private var dataController = SupabaseDataController.shared
    @State private var isLoading: Bool = false
    @State private var navigateToVerify = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login as \(selectedRole)")
                .multilineTextAlignment(.center)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.pink.opacity(0.5))
                .padding(.top, 20)
                
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
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
                dataController.signInWithPassword(email: email, password: password, roleName: selectedRole) { success, error in
                    if success {
                        print("success")
                        if !dataController.isGenPass, dataController.is2faEnabled {
                            email = email
                            UserDefaults.standard.set(email, forKey: "email")
                            if dataController.roleMatched {
                                dataController.sendOTP(email: email) { success, error in
                                    if success {
                                        print("OTP sent")
                                    } else {
                                        print("Failed to send OTP: \(error ?? "Unknown error")")
                                    }
                                }
                            }
                            navigateToVerify = dataController.roleMatched
                        }
                    } else {
                        print("Cannot sign in")
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
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
        .padding()
        .alert(isPresented: $dataController.showAlert) {  // 🔹 Uses showAlert state from controller
            Alert(title: Text("Alert"), message: Text(dataController.alertMessage), dismissButton: .default(Text("OK")))
        }
        .navigationDestination(isPresented: $navigateToVerify) {
            VerifyOTPView(email: email)
        }
    }
}

struct VerifyOTPView: View {
    var email: String
    @State private var otpCode: String = ""
    @State private var isLoading = false
    @StateObject private var dataController = SupabaseDataController.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter OTP Sent to \(email)")
                .multilineTextAlignment(.center)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.pink.opacity(0.5))
                .padding(.top, 20)
            
            TextField("Enter OTP", text: $otpCode)
                .keyboardType(.numberPad)
                .padding(10)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 1)
                .padding(.horizontal, 20)

            Button(action: {
                isLoading = true
                dataController.verifyOTP(email: email, token: otpCode) { success, error in
                    isLoading = false
                    if success {
                        print("OTP verified")
                    } else {
                        print("OTP verification failed: \(error ?? "Unknown error")")
                    }
                }
            }) {
                Text("Verify OTP")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .disabled(isLoading || otpCode.isEmpty)
            
            Button(action: {
                dataController.sendOTP(email: email) { success, error in
                    if success {
                        print("OTP sent again")
                    } else {
                        print("Failed to send OTP: \(error ?? "Unknown error")")
                    }
                }
            }) {
                Text("Resend OTP")
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .padding()
        .alert(isPresented: $dataController.showAlert) {  // 🔹 Uses showAlert state from controller
            Alert(title: Text("Alert"), message: Text(dataController.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    RoleSelectionView()
}
