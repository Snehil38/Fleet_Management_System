import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @StateObject private var dataController = SupabaseDataController.shared
    
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
        }
        .padding()
    }
}

#Preview {
    LoginView()
}
