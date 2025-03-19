import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var otp: String = ""
    @StateObject private var dataController = SupabaseDataController.shared
    @State private var isLoading: Bool = false
    @State private var copiedToClipboard: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo and App Name
            Text("TrackNGo")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.pink.opacity(0.5))
                .padding(.top, 20)
            
            // App Image
            Image("image")
                .resizable()
                .scaledToFit()
                .frame(height: 250)
                .padding(.bottom, 20)
            
            // Login Title (changes based on stage)
            Text(loginStageTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            // Different view for each login stage
            Group {
                switch dataController.loginStage {
                case .email:
                    emailVerificationView
                case .otp:
                    otpVerificationView
                case .password:
                    passwordVerificationView
                }
            }
            
            // Error display
            if let error = dataController.authError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .animation(.easeInOut, value: dataController.loginStage)
        .disabled(isLoading)
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    .ignoresSafeArea()
                }
            }
        )
    }
    
    // Dynamic title based on login stage
    var loginStageTitle: String {
        switch dataController.loginStage {
        case .email:
            return "Login"
        case .otp:
            return "Verify OTP"
        case .password:
            return "Enter Password"
        }
    }
    
    // MARK: - Email Verification View
    var emailVerificationView: some View {
        VStack {
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(10)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 1)
                .padding(.horizontal, 20)
                .disabled(isLoading)
            
            Button(action: {
                isLoading = true
                dataController.verifyEmail(email: email)
                // Short delay to show loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading || email.isEmpty)
        }
    }
    
    // MARK: - OTP Verification View
    var otpVerificationView: some View {
        VStack {
            Text("Verification Required")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 2)
            
            Text("Email verification sent to")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(email)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            TextField("Enter OTP Code", text: $otp)
                .keyboardType(.numberPad)
                .padding(10)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 1)
                .padding(.horizontal, 20)
                .disabled(isLoading)
            
            HStack(spacing: 15) {
                // Back button
                Button(action: {
                    dataController.resetLoginState()
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)
                
                // Verify button
                Button(action: {
                    isLoading = true
                    dataController.verifyOTP(otpEntered: otp)
                    // Short delay to show loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                    }
                }) {
                    Text("Verify")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || otp.isEmpty)
            }
            .padding(.horizontal, 20)
            
            // Resend OTP Button
            Button(action: {
                isLoading = true
                otp = ""
                dataController.generateOTP(for: email)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Generate New Code")
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading)
            
            if let error = dataController.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Password Verification View
    var passwordVerificationView: some View {
        VStack {
            Text("Email verified")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.bottom, 5)
            
            SecureField("Password", text: $password)
                .padding(10)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 1)
                .padding(.horizontal, 20)
                .disabled(isLoading)
            
            HStack(spacing: 15) {
                // Back button
                Button(action: {
                    dataController.loginStage = .otp
                    otp = ""
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)
                
                // Sign In button
                Button(action: {
                    isLoading = true
                    dataController.signIn(email: email, password: password)
                    // Short delay to show loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isLoading = false
                    }
                }) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || password.isEmpty)
            }
            .padding(.horizontal, 20)
            
            // Forgot Password button
            Button(action: {
                isLoading = true
                dataController.resetPassword(email: email)
                // Show loading briefly
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isLoading = false
                }
            }) {
                Text("Forgot Password?")
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .padding(.top, 15)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading)
        }
    }
}

#Preview {
    LoginView()
}
