import Foundation
import FirebaseAuth
import FirebaseFirestore

/// An observable store that manages the user's memories in real-time.
/// Subscribes to Firestore updates via `MemoryService` and publishes changes to `items`.
final class MemoryStore: ObservableObject {
    
    /// Published array of memory items, observed by SwiftUI views
    @Published var items: [Memory] = []

    /// Firestore listener for real-time updates
    private var listener: ListenerRegistration?

    /// Starts listening to memory updates for the current user.
    /// Automatically maps Firestore documents to `Memory` objects.
    func startListening() {
        // Ensure a user is signed in
        guard let uid = Auth.auth().currentUser?.uid else {
            stopListening()  // Clean up if no user
            items = []
            return
        }

        // Stop any existing listener before starting a new one
        stopListening()

        // Subscribe to memories via MemoryService
        listener = MemoryService.shared.listenMemories(uid: uid) { [weak self] docs in
            let mapped = docs.map {
                Memory(
                    id: $0.id,
                    imageUrl: $0.imageUrl,
                    caption: $0.caption,
                    cafeTag: $0.cafeTag,
                    cafeId: $0.cafeId,
                    createdAt: $0.createdAt
                )
            }

            // Update published items on the main thread
            DispatchQueue.main.async { self?.items = mapped }
        }
    }

    /// Stops listening to Firestore updates and clears the listener
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// Ensures the listener is removed when the store is deallocated
    deinit { stopListening() }
}
