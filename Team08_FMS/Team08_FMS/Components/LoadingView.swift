import SwiftUI

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            
            Text(message)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    LoadingView(message: "Loading...")
} 