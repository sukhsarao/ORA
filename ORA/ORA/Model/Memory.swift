import SwiftUI

/// A model representing a user memory associated with a café.
struct Memory: Identifiable, Equatable {
    /// A unique identifier for the memory.
    let id: String
    
    /// The URL of the memory image.
    let imageUrl: String
    
    /// A user-provided caption describing the memory.
    var caption: String
    
    /// The tag or name of the associated café.
    var cafeTag: String
    
    /// The unique identifier of the related café, if available.
    let cafeId: String?
    
    /// The date and time when the memory was created.
    var createdAt: Date
}
