import Foundation
import SwiftData

/// A persisted model representing a saved folder that groups cafes.
/// Linked to its cafes using a cascading relationship.
@Model
final class FolderSD {
    @Attribute(.unique) var id: String
    var name: String
    var ownerUID: String
    @Relationship(deleteRule: .cascade, inverse: \CafeRefSD.folder)
    var cafeRefs: [CafeRefSD]
    //
    init(id: String = UUID().uuidString, name: String, ownerUID: String, cafeRefs: [CafeRefSD] = []) {
        self.id = id
        self.name = name
        self.ownerUID = ownerUID
        self.cafeRefs = cafeRefs
    }
}

/// A reference to a cafe stored inside a folder.
/// Used to model many-to-one relationships in SwiftData.
@Model
final class CafeRefSD {
    var cafeID: String
    var folder: FolderSD?

    init(cafeID: String, folder: FolderSD? = nil) {
        self.cafeID = cafeID
        self.folder = folder
    }
}
