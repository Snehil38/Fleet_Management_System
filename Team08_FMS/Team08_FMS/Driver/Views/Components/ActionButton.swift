import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 10) {
            ActionButton(title: "Start Navigation", icon: "location.fill", color: .blue) {}
            ActionButton(title: "Pre-Trip Inspection", icon: "checklist", color: .orange) {}
        }
        ActionButton(title: "Mark Delivered", icon: "checkmark.circle.fill", color: .green) {}
    }
    .padding()
} 