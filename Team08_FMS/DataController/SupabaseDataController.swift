// Removing getAllPickupPoints method as it's no longer needed

// ... existing code ... 

func fetchAllExpense() async throws -> [Expense] {
    // Fetch expenses from Supabase filtered by requestID
    let response = try await supabase
        .from("expense")
        .select()
        .execute()
    
    // Configure DateFormatter for timestamp decoding
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    // Configure JSONDecoder with the custom date decoding strategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    
    // Decode JSON into an array of Expense objects
    let expenses = try decoder.decode([Expense].self, from: response.data)
    
    return expenses
}

// ... existing code ... 