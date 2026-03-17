import Foundation
import SwiftUI

/// Utility functions for working with `Cafe` models.
struct CafeUtils {
    /// Returns the top trending cafes based on saves in the last 7 days.
    /// - Parameters:
    ///   - cafes: Array of cafes to evaluate.
    ///   - count: Number of top cafes to return (default 5).
    /// - Returns: Array of trending cafes, sorted descending by saves.
    static func getTrendingCafes(from cafes: [Cafe], count: Int = 4) -> [Cafe] {
        let trending = cafes
            .sorted { $0.savesLast7Days > $1.savesLast7Days }
            .prefix(count)
        return Array(trending)
    }
}


