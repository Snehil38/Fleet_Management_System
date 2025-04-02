import Foundation
import SwiftUI

// String extension for localization
extension String {
    var localized: String {
        let languageManager = LanguageManager.shared
        let language = languageManager.currentLanguage
        
        // Use system localization but with current selected language
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: self, comment: "")
    }
    
    // Simple formatting for strings with a single replacement value
    func localizedFormat(_ argument: CVarArg) -> String {
        return String(format: self.localized, argument)
    }
    
    // Multiple replacement values
    func localizedFormat(_ arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
    
    // Convenience method for pluralization
    func localizedWithCount(_ count: Int) -> String {
        let format = self.localized
        return String.localizedStringWithFormat(format, count)
    }
} 