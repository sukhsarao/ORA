import SwiftUI

/// ViewModel for managing app settings, specifically the theme mode.
/// Uses `@Published` to notify SwiftUI views of changes.
@MainActor
final class SettingsViewModel: ObservableObject {
    
    /// Current theme selected by the user
    @Published var theme: ThemeMode
    
    /// Reference to the underlying ThemeManager responsible for persisting the setting
    private let themeManager: ThemeManager

    /// Initializes the ViewModel with the current theme from ThemeManager
    /// - Parameter themeManager: The manager responsible for reading and writing theme settings
    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        self.theme = themeManager.themeMode
    }

    /// Persists the current theme selection using ThemeManager
    func save() {
        themeManager.setThemeMode(theme)
    }
}
