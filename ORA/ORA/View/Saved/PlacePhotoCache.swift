import Foundation

/// A lightweight in-memory cache for storing place photo URLs by name.
/// Used to avoid repeated network lookups for the same place.
public enum PlacePhotoCache {
    private static var map: [String: URL] = [:]

    /// Access or update a cached URL using a string key.
    public static subscript(key: String) -> URL? {
        get { map[key] }
        set { map[key] = newValue }
    }

    /// Clears all cached photo URLs.
    public static func clear() { map.removeAll() }

    /// Shared access point for the cache.
    public static var shared: PlacePhotoCache.Type { self }
}
