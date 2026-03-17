import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct MemoryDoc: Identifiable {
    /// The unique identifier of the memory document.
    let id: String
    
    /// The ID of the user who created the memory.
    let userId: String
    
    /// The URL of the memory image.
    let imageUrl: String
    
    /// The caption or description associated with the memory.
    let caption: String
    
    /// The tag or name of the related café.
    let cafeTag: String
    
    /// The unique identifier of the associated café, if available.
    let cafeId: String?
    
    /// A flag indicating whether the memory is visible to the public.
    let isPublic: Bool
    
    /// The timestamp when the memory was created.
    let createdAt: Date
}

/// Errors that can occur when interacting with `MemoryService`.
enum MemoryServiceError: Error {
    /// The user is not signed in.
    case notSignedIn
    /// The provided image could not be converted to data.
    case badImage
    /// The generated URL for S3 upload is invalid.
    case badURL
}

/// A singleton service responsible for creating, fetching, listening to, and deleting user memories.
final class MemoryService {
    /// Shared singleton instance.
    static let shared = MemoryService()
    private init() {}
    private let db = Firestore.firestore()
    
    // MARK: - Memory Creation
    
    /// Uploads an image to S3, creates a Firestore memory document, and updates related café data.
    ///
    /// - Parameters:
    ///   - image: The memory image to upload.
    ///   - caption: A caption describing the memory.
    ///   - cafeTag: The café name associated with the memory.
    ///   - selectedCafe: Optional `Cafe` object to resolve the ID.
    ///   - isPublic: Indicates whether the memory is publicly visible.
    ///   - cafeId: Optional explicit café ID.
    ///   - jpegQuality: Compression quality for the JPEG image (0–1.0).
    /// - Returns: The created `MemoryDoc` object.
    /// - Throws: `MemoryServiceError` if the user is not signed in, image conversion fails, or URL is invalid.
    @discardableResult
    func createMemory(image: UIImage,
                      caption: String,
                      cafeTag: String,
                      selectedCafe: Cafe? = nil,
                      isPublic: Bool,
                      cafeId: String? = nil,
                      jpegQuality: CGFloat = 0.9) async throws -> MemoryDoc {
        guard let uid = Auth.auth().currentUser?.uid else { throw MemoryServiceError.notSignedIn }
        guard let data = image.jpegData(compressionQuality: jpegQuality) else { throw MemoryServiceError.badImage }

        // 1) Presign S3 upload
        let info = try await S3Presign.requestUploadURL(contentType: "image/jpeg", uid: uid, folder: "memories")
        guard let putURL = URL(string: info.uploadUrl) else { throw MemoryServiceError.badURL }
        try await S3Presign.putToS3(uploadUrl: putURL, data: data, contentType: info.contentType)
        
        // 2) Resolve café ID if not provided
        var resolvedCafeId: String? = cafeId
        if resolvedCafeId == nil, let c = selectedCafe?.id { resolvedCafeId = c }
        let trimmedName = cafeTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedCafeId == nil, !trimmedName.isEmpty {
            let snap = try await db.collection("cafes")
                .whereField("name", isEqualTo: trimmedName)
                .limit(to: 1)
                .getDocuments()
            if let doc = snap.documents.first { resolvedCafeId = doc.documentID }
        }

        // 3) Create Firestore document
        let payload: [String: Any] = [
            "userId": uid,
            "imageUrl": info.fileUrl,
            "caption": caption,
            "cafeTag": trimmedName,
            "cafeId": resolvedCafeId as Any,
            "isPublic": isPublic,
            "createdAt": Timestamp(date: Date())
        ]
        let ref = try await db.collection("users").document(uid)
            .collection("memories")
            .addDocument(data: payload)
        
        // 4) Update visited cafés
        if !trimmedName.isEmpty {
            try await db.collection("users").document(uid)
                .updateData(["visitedCafes": FieldValue.arrayUnion([trimmedName])])
        }

        // 5) Update café recents if public
        if isPublic, let cid = resolvedCafeId {
            try await db.collection("cafes").document(cid)
                .updateData(["recents": FieldValue.arrayUnion([info.fileUrl])])
        }

        return MemoryDoc(
            id: ref.documentID,
            userId: uid,
            imageUrl: info.fileUrl,
            caption: caption,
            cafeTag: trimmedName,
            cafeId: resolvedCafeId,
            isPublic: isPublic,
            createdAt: Date()
        )
    }
    
    // MARK: - Memory Fetching
    
    /// Fetches all memories for a specific user, ordered by creation date descending.
    /// - Parameter uid: The user ID to fetch memories for.
    /// - Returns: An array of `MemoryDoc` objects.
    /// - Throws: Firestore errors.
    func fetchMemories(uid: String) async throws -> [MemoryDoc] {
        let snap = try await db.collection("users").document(uid)
            .collection("memories")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snap.documents.compactMap { d in
            let x = d.data()
            return MemoryDoc(
                id: d.documentID,
                userId: x["userId"] as? String ?? uid,
                imageUrl: x["imageUrl"] as? String ?? "",
                caption: x["caption"] as? String ?? "",
                cafeTag: x["cafeTag"] as? String ?? "",
                cafeId: x["cafeId"] as? String,
                isPublic: x["isPublic"] as? Bool ?? false,
                createdAt: (x["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    // MARK: - Memory Listening
    
    /// Adds a real-time listener for a user’s memories.
    /// - Parameters:
    ///   - uid: The user ID to listen for.
    ///   - onChange: Closure called with the updated array of `MemoryDoc` objects.
    /// - Returns: A Firestore `ListenerRegistration` that can be used to remove the listener.
    func listenMemories(uid: String, onChange: @escaping ([MemoryDoc]) -> Void) -> ListenerRegistration {
        db.collection("users").document(uid)
            .collection("memories")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, err in
                guard err == nil, let docs = snap?.documents else { onChange([]); return }
                let list = docs.map { d -> MemoryDoc in
                    let x = d.data()
                    return MemoryDoc(
                        id: d.documentID,
                        userId: x["userId"] as? String ?? uid,
                        imageUrl: x["imageUrl"] as? String ?? "",
                        caption: x["caption"] as? String ?? "",
                        cafeTag: x["cafeTag"] as? String ?? "",
                        cafeId: x["cafeId"] as? String,
                        isPublic: x["isPublic"] as? Bool ?? false,
                        createdAt: (x["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                onChange(list)
            }
    }

    // MARK: - Memory Deletion
    
    /// Deletes a memory from S3 and Firestore, and updates related café recents.
    /// - Parameters:
    ///   - docId: The Firestore document ID of the memory.
    ///   - imageUrl: The S3 image URL to delete.
    ///   - cafeId: Optional café ID to remove the memory from recents.
    /// - Throws: `MemoryServiceError` if the user is not signed in or URL is invalid, or Firestore/S3 errors.
    func deleteMemory(docId: String, imageUrl: String, cafeId: String? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw MemoryServiceError.notSignedIn }

        // 1) Delete S3 object
        guard let u = URL(string: imageUrl) else { throw MemoryServiceError.badURL }
        let key = u.path.hasPrefix("/") ? String(u.path.dropFirst()) : u.path
        try await S3Presign.deleteObject(key: key, uid: uid)

        // 2) Delete Firestore document
        try await db.collection("users").document(uid)
            .collection("memories").document(docId).delete()

        // 3) Remove from café recents
        if let cafeId = cafeId, !cafeId.isEmpty {
            let cafeRef = db.collection("cafes").document(cafeId)
            try await cafeRef.updateData([
                "recents": FieldValue.arrayRemove([imageUrl])
            ])
        }
    }
}
