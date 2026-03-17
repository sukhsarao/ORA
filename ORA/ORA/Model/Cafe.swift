import Foundation
import FirebaseFirestore

/// A model representing a café, including Firestore metadata, location, and enrichment data.
struct Cafe: Identifiable, Codable, Equatable, Hashable {
    /// The unique Firestore document identifier for the café.
    @DocumentID var id: String?
    
    /// The name of the café.
    var name: String
    
    /// A primary image URL for the café.
    var imageUrl: String?
    
    /// A list of available amenities (e.g., Wi-Fi, outdoor seating).
    var amenities: [String]?
    
    /// The timestamp when the café record was created.
    var createdAt: Date?
    
    // MARK: - Places Enrichment
    
    /// The street address of the café.
    var address: String?
    
    /// The geographic latitude of the café.
    var latitude: Double?
    
    /// The geographic longitude of the café.
    var longitude: Double?
    
    /// The average user rating of the café.
    var rating: Double?
    
    /// A collection of remote image URLs related to the café.
    var imageURLs: [URL]?
    
    /// A list of featured or promotional menu items.
    var specials: [MenuItem] = []
    
    /// Recently interacted user identifiers or session IDs.
    var recents: [String]?
    
    /// The IDs of the associated specials.
    var specialsIDs: [String] = []
    
    // MARK: - Trending Metrics
    
    /// The total number of saves in the last seven days.
    var savesLast7Days: Int = 0
    
    /// A list of recent save timestamps used for trending calculations.
    var lastSaveTimestamps: [Timestamp] = []
}

/// A lightweight model optimized for use in widgets, containing only essential café data.
struct WidgetCafe: Codable, Identifiable {
    /// The unique identifier of the café.
    let id: String
    
    /// The name of the café.
    let name: String
    
    /// The main image URL of the café.
    let imageUrl: String?
    
    /// The average rating of the café.
    let rating: Double?
    
    /// The latitude of the café’s location.
    let latitude: Double?
    
    /// The longitude of the café’s location.
    let longitude: Double?
    
    /// The number of saves in the last seven days.
    let savesLast7Days: Int
}

/// A wrapper model representing a collection of widget cafés.
struct CafeList: Codable {
    /// The list of cafés displayed in a widget context.
    let cafes: [WidgetCafe]
}
