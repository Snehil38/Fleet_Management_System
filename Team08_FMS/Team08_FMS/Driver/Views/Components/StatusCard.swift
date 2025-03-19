import SwiftUI

struct StatusCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 18, weight: .medium))
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusCard(
            icon: "clock.fill",
            title: "ETA",
            value: "25 mins",
            color: .blue
        )
        
        StatusCard(
            icon: "arrow.left.and.right",
            title: "Distance",
            value: "8.5 km",
            color: .green
        )
    }
    .padding()
} 