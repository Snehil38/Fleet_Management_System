import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @StateObject private var dataController = SupabaseDataController.shared
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showAlert: Bool = false
    
    var body: some View {
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
            
            Text("Login!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
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
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Button(action: {
                SupabaseDataController.shared.signIn(email: email, password: password)
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
        .alert(isPresented: Binding<Bool>(
                    get: { dataController.authError != nil },  // Show alert when error exists
                    set: { _ in dataController.authError = nil }  // Reset error on dismiss
        )) {
            Alert(title: Text("Login Failed"),
                  message: Text(dataController.authError ?? "Unknown error."),
                  dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    LoginView()
}
