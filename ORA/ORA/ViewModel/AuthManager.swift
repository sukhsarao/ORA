import Foundation
import FirebaseAuth
import FirebaseFirestore

/// ObservableObject managing user authentication, profile, and saved/pinned cafes.
class AuthManager: ObservableObject {
    
    /// Current signed-in user
       @Published var currentUser: User? = nil
       
       /// Firestore reference
       private let db = Firestore.firestore()
       
       /// Auth state listener handle
       private var handle: AuthStateDidChangeListenerHandle?
       
       /// Loading state while checking auth
       @Published var isLoading = true
    
    // Check if there is a current user otherwise set it to null.
    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.fetchUser(uid: user.uid)
            } else {
                DispatchQueue.main.async { // Uses main thread to check if a user exists in the current session during startup.
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
        }
    }

    
    // MARK: - Sign Up
    /// Creates a new user account with unique username and email/password

    func signUp(username: String, email: String, password: String, completion: @escaping (Error?) -> Void) {
        // Check if username already exists
        db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }
                // Error message if username already exists
                if let docs = snapshot?.documents, !docs.isEmpty {
                    completion(NSError(domain: "AuthManager",
                                       code: 1,
                                       userInfo: [NSLocalizedDescriptionKey: "That username is already taken."]))
                    return
                }
                
                // Username is unique — proceed with Firebase Auth signup
                Auth.auth().createUser(withEmail: email, password: password) { result, error in
                    if let error = error {
                        completion(error)
                        return
                    }
                    guard let self = self, let user = result?.user else { return }
                    // Create new user
                    let newUser: [String: Any] = [
                        "id": user.uid,
                        "username": username,
                        "email": email,
                        "savedCafes": [],
                        "visitedCafes": [],
                        "pinnedCafes": [],
                        "location": NSNull(),
                        "profilePhotoUrl": NSNull(),
                        "createdAt": Timestamp()
                    ]
                    
                    // Add the new user to the database
                    self.db.collection("users").document(user.uid).setData(newUser) { error in
                        if let error = error {
                            completion(error)
                        } else {
                            // Set the current user to the newly created user.
                            self.currentUser = User(id: user.uid, username: username, email: email)
                            completion(nil)
                        }
                    }
                }
            }
    }

    
    // MARK: - Login with Username
    /// Login via username and password

    func login(username: String, password: String, completion: @escaping (Error?) -> Void) {
        // Query Firestore to get email from username
        db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }
                // Checks if username exists.  If it does use that users email and password to login
                // Firebase auth uses email and password to login. Username is a custom feature.
                guard let doc = snapshot?.documents.first,
                      let email = doc.data()["email"] as? String else {
                    completion(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Username not found"]))
                    return
                }
                
                // Sign in using email/password
                Auth.auth().signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        completion(error)
                    } else {
                        self.fetchUser(uid: result!.user.uid)
                        completion(nil)
                    }
                }
            }
    }
    
    // MARK: - Fetch User from Firestore
    /// Fetch full user info from Firestore

    private func fetchUser(uid: String) {
        // get user from the users table
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Fetch user error:", error)
                return
            }
            guard let data = snapshot?.data() else { return }
            // Use the User Model and create a User
            let user = User(
                id: data["id"] as? String ?? uid,
                username: data["username"] as? String ?? "Unknown",
                email: data["email"] as? String ?? "",
                savedCafes: data["savedCafes"] as? [String] ?? [],
                visitedCafes: data["visitedCafes"] as? [String] ?? [],
                pinnedCafes: data["pinnedCafes"] as? [String] ?? [],
                location: data["location"] as? GeoPoint,
                profilePhotoUrl: data["profilePhotoUrl"] as? String,
                createdAt: data["createdAt"] as? Timestamp ?? Timestamp()
            )
            // Return to main thread
            DispatchQueue.main.async {
                self.currentUser = user
                self.isLoading = false
            }
        }
    }

    
    // MARK: - Update saved cafes
    /// Function to update the saved cafes for the current user.
    func updateSavedCafes(_ cafeIds: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Updates the saved cafes associated to a user
        db.collection("users").document(uid).updateData([
            "savedCafes": cafeIds
        ]) { error in
            if let error = error {
                print("Failed to update savedCafes:", error)
            } else {
                print("savedCafes updated in Firestore") // Debug statement to ensure it updated in the DB
                DispatchQueue.main.async {
                    self.currentUser?.savedCafes = cafeIds
                }
            }
        }
    }
    
    /// Helper: Add or remove a single cafe
    func toggleSavedCafe(cafeId: String) {
        guard var user = currentUser else { return }
        
        if user.savedCafes.contains(cafeId) {
            // Remove it
            user.savedCafes.removeAll { $0 == cafeId }
        } else {
            // Add it
            user.savedCafes.append(cafeId)
        }
        
        updateSavedCafes(user.savedCafes)
    }
    
    /// Function to logout the current user using Firebase Authenctication
    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil // Set the current User to nil.
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

}

extension AuthManager {
    
    // MARK: - Firestore Reference
    /// Shortcut for the `users` collection in Firestore
    private var usersRef: CollectionReference { Firestore.firestore().collection("users") }
    
    // MARK: - Saved Cafes
    
    /// Adds a cafe ID to the current user's saved cafes in Firestore
    /// - Parameters:
    ///   - cafeId: The ID of the cafe to save
    ///   - completion: Completion handler called with optional error
    func addSavedCafeID(_ cafeId: String, completion: @escaping (Error?) -> Void) {
        guard let uid = currentUser?.id ?? Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "AuthManager", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "Not signed in"]))
            return
        }
        usersRef.document(uid).updateData([
            "savedCafes": FieldValue.arrayUnion([cafeId])
        ], completion: completion)
    }

    /// Removes a cafe ID from the current user's saved cafes in Firestore
    /// - Parameters:
    ///   - cafeId: The ID of the cafe to remove
    ///   - completion: Completion handler called with optional error
    func removeSavedCafeID(_ cafeId: String, completion: @escaping (Error?) -> Void) {
        guard let uid = currentUser?.id ?? Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "AuthManager", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "Not signed in"]))
            return
        }
        usersRef.document(uid).updateData([
            "savedCafes": FieldValue.arrayRemove([cafeId])
        ], completion: completion)
    }

    /// Listens to changes in the current user's saved cafes
    /// - Parameter onChange: Closure called with updated array of cafe IDs
    /// - Returns: ListenerRegistration which can be removed to stop listening
    func listenSavedCafeIDs(onChange: @escaping ([String]) -> Void) -> ListenerRegistration? {
        guard let uid = currentUser?.id ?? Auth.auth().currentUser?.uid else { return nil }
        return usersRef.document(uid).addSnapshotListener { snap, _ in
            let ids = (snap?.data()?["savedCafes"] as? [String]) ?? []
            onChange(ids)
        }
    }

    // MARK: - Profile Updates
    
    /// Updates the current user's display name and/or avatar photo
    /// - Parameters:
    ///   - displayName: The new username
    ///   - avatarData: Optional image data for avatar
    ///   - completion: Completion handler called with optional error
    func updateProfile(displayName: String,
                       avatarData: Data?,
                       completion: @escaping (Error?) -> Void) {
        guard let uid = currentUser?.id ?? Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "AuthManager", code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "No signed-in user"]))
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        let oldName = currentUser?.username ?? Auth.auth().currentUser?.displayName ?? ""
        let nameChanged = displayName.trimmingCharacters(in: .whitespacesAndNewlines) != oldName
        let hasNewAvatar = (avatarData?.isEmpty == false)

        // No updates needed
        if !nameChanged && !hasNewAvatar {
            completion(nil)
            return
        }

        /// Apply updates locally and in Firestore
        func applyUpdates(username newName: String?, photoURL: String?) {
            var updates: [String: Any] = [:]
            if let newName { updates["username"] = newName }
            if let photoURL { updates["profilePhotoUrl"] = photoURL }

            userRef.updateData(updates) { [weak self] err in
                if let err { completion(err); return }
                Task { @MainActor in
                    self?.applyLocalProfileChanges(uid: uid,
                                                   displayName: newName ?? oldName,
                                                   photoURL: photoURL)
                    completion(nil)
                }
            }
        }

        /// Ensure new username is not taken
        func ensureNameIfNeeded(_ proceed: @escaping () -> Void) {
            guard nameChanged else { proceed(); return }
            db.collection("users")
                .whereField("username", isEqualTo: displayName)
                .getDocuments { snap, err in
                    if let err { completion(err); return }
                    if let docs = snap?.documents,
                       docs.contains(where: { $0.documentID != uid }) {
                        completion(NSError(domain: "AuthManager", code: 2,
                                           userInfo: [NSLocalizedDescriptionKey: "That username is taken."]))
                        return
                    }
                    proceed()
                }
        }

        // Validate username first
        ensureNameIfNeeded {
            if hasNewAvatar, let data = avatarData {
                Task {
                    do {
                        let urlStr = try await self.uploadAvatarToS3(uid: uid, data: data)
                        applyUpdates(username: nameChanged ? displayName : nil,
                                     photoURL: urlStr)
                    } catch {
                        completion(error)
                    }
                }
            } else {
                applyUpdates(username: displayName, photoURL: nil)
            }
        }
    }

    /// Uploads avatar image to S3 and returns the URL
    /// - Parameters:
    ///   - uid: User ID
    ///   - data: Image data
    /// - Returns: URL string of uploaded image
    private func uploadAvatarToS3(uid: String, data: Data) async throws -> String {
        let info = try await S3Presign.requestUploadURL(
            contentType: "image/jpeg",
            uid: uid,
            folder: "profile_photos"
        )
        guard let putURL = URL(string: info.uploadUrl) else { throw URLError(.badURL) }
        try await S3Presign.putToS3(uploadUrl: putURL, data: data, contentType: info.contentType)
        return info.fileUrl
    }

    /// Applies profile changes locally and updates Firebase Auth profile
    /// - Parameters:
    ///   - uid: User ID
    ///   - displayName: New display name
    ///   - photoURL: Optional avatar URL
    @MainActor
    private func applyLocalProfileChanges(uid: String,
                                          displayName: String,
                                          photoURL: String?) {
        if currentUser == nil {
            currentUser = User(id: uid,
                               username: displayName,
                               email: Auth.auth().currentUser?.email ?? "")
        } else {
            currentUser?.username = displayName
            if let photoURL { currentUser?.profilePhotoUrl = photoURL }
        }

        if let change = Auth.auth().currentUser?.createProfileChangeRequest() {
            change.displayName = displayName
            if let photoURL, let u = URL(string: photoURL) { change.photoURL = u }
            change.commitChanges(completion: nil)
        }
    }

    // MARK: - Pinned Cafes
    
    /// Toggle a cafe in the pinned cafes array
    /// - Parameter cafeId: Cafe ID to pin or unpin
    func togglePinnedCafe(cafeId: String) {
        guard let uid = currentUser?.id ?? Auth.auth().currentUser?.uid else { return }

        var updated = currentUser?.pinnedCafes ?? []
        if updated.contains(cafeId) {
            updated.removeAll { $0 == cafeId }
            usersRef.document(uid).updateData([
                "pinnedCafes": FieldValue.arrayRemove([cafeId])
            ])
        } else {
            updated.append(cafeId)
            usersRef.document(uid).updateData([
                "pinnedCafes": FieldValue.arrayUnion([cafeId])
            ])
        }

        DispatchQueue.main.async {
            self.currentUser?.pinnedCafes = updated
        }
    }
}

// MARK: - ProfileUpdating
extension AuthManager: ProfileUpdating {}
