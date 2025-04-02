import Foundation
import SwiftUI

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") private var appLanguage: String = ""
    
    private init() {
        // If no language is saved, use the device language by default
        if appLanguage.isEmpty {
            appLanguage = Locale.current.languageCode ?? "en"
        }
    }
    
    var currentLanguage: String {
        appLanguage.isEmpty ? (Locale.current.languageCode ?? "en") : appLanguage
    }
    
    func setLanguage(_ languageCode: String) {
        appLanguage = languageCode
        
        // Post notification to update UI components
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    func getLocalizedValue(for key: String) -> String {
        let bundle = Bundle.main
        
        // Get localized string based on the current language
        let localizedString = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        
        return localizedString
    }
}

// String extension for easy localization
//extension String {
//    var localized: String {
//        return LanguageManager.shared.getLocalizedValue(for: self)
//    }
//}
