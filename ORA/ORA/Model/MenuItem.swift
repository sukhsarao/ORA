import SwiftUI
import FirebaseFirestore

/// A model representing a menu item offered by a café.
struct MenuItem: Identifiable, Codable, Equatable, Hashable {
    /// The unique Firestore document identifier for the menu item.
    @DocumentID var id: String?
    
    /// The display name of the menu item.
    var name: String
    
    /// The URL of the item's image, if available.
    var imageUrl: String?
    
    /// A short description of the menu item.
    var description: String?
    
    /// The base price of the item, formatted as a string.
    var price: String?
    
    /// A mapping of size labels to their corresponding prices (e.g., `"small": "3.5"`).
    var sizes: [String: String]?
    
    /// The category of the item, such as `"food"` or `"drink"`.
    var type: String
}
