import SwiftUI
import Foundation

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let languages = [
        ("English", "en"),
        ("Español", "es"),
        ("हिंदी", "hi")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Choose Language".localized)) {
                    ForEach(languages, id: \.1) { language in
                        Button(action: {
                            languageManager.setLanguage(language.1)
                        }) {
                            HStack {
                                Text(language.0)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if languageManager.currentLanguage == language.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Text("The app will use the selected language for all text elements.".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
} 