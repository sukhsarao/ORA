import Foundation

/// Basic result row we show in lists from firebase
public struct Row: Identifiable, Equatable{
    /// We use cafe ID + lowercased item name to keep rows unique.
    public var id: String { "\(cafeId)|\(itemName.lowercased())" }

    public let cafeId: String
    public let itemName: String
    public let price: Double?
    public let cafeName: String
    public let imageURL: URL?
    public let cafeAddress: String?
    public let cafeRating: Double?
}

/// Compact form we save to SwiftData (snapshots).
struct RowCodable: Codable {
    let cafeId: String
    let itemName: String
    let price: Double?
    let cafeName: String
    let imageURL: URL?
    let cafeAddress: String?
    let cafeRating: Double?
}

/// One recent search entry we can show and restore.
struct RecentItem: Identifiable {
    var id: String { query }
    let query: String
    let rows: [Row]
    let when: Date
}

/// Menu doc + its parent cafe info and Firestore path.
struct MenuJoin {
    let item: MenuItemDecodable
    let cafeId: String?
    let path: String
}

/// Minimal menu item shape we decode from Firestore.
struct MenuItemDecodable: Codable {
    var name: String
    var imageUrl: String?
    var description: String?
    var price: String?
    var sizes: [String: String]?
    var type: String?
}
