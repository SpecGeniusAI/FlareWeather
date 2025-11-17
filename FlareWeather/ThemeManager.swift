import SwiftUI

enum ColorSchemePreference: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var userInterfaceStyle: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("colorSchemePreference") var colorSchemePreference: ColorSchemePreference = .system
    
    var colorScheme: ColorScheme? {
        colorSchemePreference.userInterfaceStyle
    }
}

