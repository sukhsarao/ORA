import SwiftUI

/// Represents the available tabs in the ORA app.
/// Each case corresponds to one main section of the app.
enum ORATab: Int, CaseIterable {
    /// User profile section
    case profile = 0
    /// Search cafes or content
    case search
    /// Home / swipe deck section
    case home
    /// Map view of cafes
    case map
    /// Saved cafes
    case save
    /// SF Symbol icon associated with each tab (used in bottom bar)
    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .search:  return "magnifyingglass"
        case .home:    return "house.fill"
        case .map:     return "mappin.and.ellipse"
        case .save:    return "square.and.arrow.down.fill"
        }
    }
    /// Human-readable label for each tab (for accessibility and potential label-based UI)
    var label: String {
        switch self {
        case .profile: return "Profile"
        case .search:  return "Search"
        case .home:    return "Home"
        case .map:     return "Map"
        case .save:    return "Save"
        }
    }
}
