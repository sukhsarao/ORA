import Foundation

/// A folder of saved cafes.
struct SavedFolder: Identifiable, Hashable {
    let id: String          // Unique ID
    var name: String        // Folder name
    var cafes: [Cafe]       // Cafes in this folder

    init(id: String = UUID().uuidString, name: String, cafes: [Cafe] = []) {
        self.id = id
        self.name = name
        self.cafes = cafes
    }
}
