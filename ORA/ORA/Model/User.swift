import FirebaseFirestore

/// A model representing an application user and their café interactions.
struct User: Identifiable {
    /// The unique identifier for the user.
    var id: String
    
    /// The user’s chosen display name.
    var username: String
    
    /// The user’s email address.
    var email: String
    
    /// A list of café IDs the user has saved.
    var savedCafes: [String] = []
    
    /// A list of café IDs the user has marked as visited.
    var visitedCafes: [String] = []
    
    /// A list of café IDs the user has pinned or favorited.
    var pinnedCafes: [String] = []
    
    /// The user’s last known geographic location.
    var location: GeoPoint? = nil
    
    /// The URL of the user’s profile photo.
    var profilePhotoUrl: String? = nil
    
    /// The timestamp when the user record was created.
    var createdAt: Timestamp = Timestamp()
}
