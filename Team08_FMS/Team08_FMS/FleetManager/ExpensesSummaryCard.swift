import SwiftUICore
import SwiftUI

struct ExpensesSummaryCard: View {
    @StateObject private var calculator = FinanceCalculator.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Expenses")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(calculator.getExpenseBreakdown(), id: \.0) { category, amount in
                    HStack {
                        Text(category)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", amount))")
                            .fontWeight(.medium)
                    }
                    if category != calculator.getExpenseBreakdown().last?.0 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", calculator.calculateTotalExpenses()))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
} 
