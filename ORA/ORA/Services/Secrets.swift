import Foundation

/// Utility to securely access keys and secrets stored in `SECRETS.plist`.
enum Secrets {
    
    /// Retrieves the value for a given key from `SECRETS.plist`.
    /// - Parameter key: The key to look up.
    /// - Returns: The string value if found; otherwise, an empty string.
    static func value(for key: String) -> String {
        //looks for hte file named SECRETS.plist..
        guard let url = Bundle.main.url(forResource: "SECRETS", withExtension: "plist") else {
            return ""
        }

        //loads raw data..
        guard let data = try? Data(contentsOf: url) else {
            return ""
        }

        //deserialize into swift dictionary
        let dict = (try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )) as? [String: Any]

        if let v = dict?[key] as? String, !v.isEmpty {
            return v
        }

        return ""
    }
    
    /// Access key for Unsplash API.
    static var unsplashAccessKey: String {
        value(for: "UNSPLASH_ACCESS_KEY")
    }
    
    /// API key for Google Places.
    static var googlePlacesAPIKey: String {
        value(for: "GOOGLE_PLACES_API_KEY")
    }
}
