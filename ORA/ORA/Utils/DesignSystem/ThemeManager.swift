import SwiftUI

/// Manages the app's theme, persisting the selected mode in `UserDefaults`.
final class ThemeManager: ObservableObject {
    /// Currently selected theme mode.
    @Published var theme: ThemeMode

    private let key = "ora.theme"

    /// Initializes the manager, loading saved theme or defaulting to `.system`.
    init() {
        let raw = UserDefaults.standard.string(forKey: key)
        theme = ThemeMode(rawValue: raw ?? "system") ?? .system
    }

    /// Sets the current theme and persists it.
    /// - Parameter mode: The new theme mode.
    func set(_ mode: ThemeMode) {
        theme = mode
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }

    /// Convenience accessor for the current theme mode.
    var themeMode: ThemeMode { theme }

    /// Alias for `set(_:)`.
    func setThemeMode(_ mode: ThemeMode) { set(mode) }
}

/// Represents the available theme modes in the app.
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    /// Human-readable title for the mode.
    var title: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// Corresponding `ColorScheme` for SwiftUI views.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
