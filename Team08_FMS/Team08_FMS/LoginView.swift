import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    
    var body: some View {
        NavigationView {
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
                
                Text("Welcome Back !")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                TextField("Email", text: $username)
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
                    // Handle login action
                    SupabaseDataController.shared.signIn(email: "driver@example.com", password: "1234") { result in
                        switch result {
                        case .success:
                            print("✅ Sign-in successful!")
                            
                        case .failure(let error):
                            print("❌ Sign-in failed: \(error.localizedDescription)")
                        }
                    }
                    print("Logging in with username: \(username) and password: \(password)")
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

        }
    }
}

#Preview {
    LoginView()
} 
