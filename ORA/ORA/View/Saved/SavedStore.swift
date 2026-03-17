import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Observable store managing a user's saved cafes and folders.
/// Handles local UI state, SwiftData persistence, and Firestore syncing.
@MainActor
final class SavedStore: ObservableObject {
    // live UI state
    @Published var liked: [Cafe] = []                 // all saved cafes (flat list)
    @Published var folders: [SavedFolder] = []        // user folders (each holds cafes)
    @Published private(set) var savedIDs: [String] = [] // saved cafe IDs (from Firestore)

    // infra
    private var userListener: ListenerRegistration?   // listener for user’s saved IDs
    var modelContext: ModelContext?                   // SwiftData context (injected)

    deinit { userListener?.remove() }

    // inject SwiftData context from views
    func attachModelContext(_ ctx: ModelContext) { self.modelContext = ctx }

    // start listening to current user’s saved IDs
    func bindToUser() {
        userListener?.remove()
        userListener = AuthManager().listenSavedCafeIDs { [weak self] ids in
            guard let self else { return }
            self.savedIDs = ids
            Task {
                await self.loadLikedFromFirestore(ids: ids) // fills liked[]
                await self.loadFoldersFromSwiftData()        // fills folders[]
            }
        }
    }

    // clear local state on logout
    func onLogout() {
        userListener?.remove(); userListener = nil
        liked = []; savedIDs = []; folders = []
    }

    
    
    
    // MARK: Folders
    /// Create a new folder (SwiftData only)
    func addFolder(name: String) {
        guard let uid = Auth.auth().currentUser?.uid,
              let ctx = modelContext else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let folderSD = FolderSD(name: trimmed, ownerUID: uid)
        ctx.insert(folderSD)
        try? ctx.save()

        // reflect in-memory immediately
        folders.append(SavedFolder(id: folderSD.id, name: folderSD.name, cafes: []))
    }

    /// Delete a folder and its references (SwiftData only; cafes remain globally saved)
    func deleteFolder(_ folder: SavedFolder) {
        guard let ctx = modelContext,
              let uid = Auth.auth().currentUser?.uid else { return }

        if let folderSD = try? fetchFolderSD(by: folder.id, ownerUID: uid, ctx: ctx) {
            ctx.delete(folderSD)
            try? ctx.save()
        }
        folders.removeAll { $0.id == folder.id }
    }

    
    
    
    // MARK: Move (SwiftData only does NOT affect “Saved” in Firestore)

    /// Move a cafe into a target folder. Does not affect global saved state.
    func moveCafe(_ cafe: Cafe, to folder: SavedFolder) {
        guard let ctx = modelContext,
              let uid = Auth.auth().currentUser?.uid,
              let cafeID = cafe.id else { return }

        // in-memory: remove from all folders, then add to target
        for i in folders.indices {
            folders[i].cafes.removeAll { $0.id == cafeID }
        }
        if let i = folders.firstIndex(where: { $0.id == folder.id }),
           !folders[i].cafes.contains(where: { $0.id == cafeID }) {
            folders[i].cafes.append(cafe)
        }

        // SwiftData: ensure a single CafeRef in the target folder
        do {
            // fetch all folders for this user
            let all = try ctx.fetch(
                FetchDescriptor<FolderSD>(predicate: #Predicate { $0.ownerUID == uid })
            )

            // remove existing refs for this cafe
            for f in all {
                if let ref = f.cafeRefs.first(where: { $0.cafeID == cafeID }) {
                    ctx.delete(ref)
                    if let idx = f.cafeRefs.firstIndex(of: ref) { f.cafeRefs.remove(at: idx) }
                }
            }

            // add a ref to the target folder
            if let targetSD = try fetchFolderSD(by: folder.id, ownerUID: uid, ctx: ctx) {
                let ref = CafeRefSD(cafeID: cafeID, folder: targetSD)
                ctx.insert(ref)
                targetSD.cafeRefs.append(ref)
            }

            try ctx.save()
        } catch {
            print("moveCafe SwiftData error:", error.localizedDescription)
        }
    }

    
    
    // MARK: Add / Remove (global “Saved”)

    /// Save a cafe globally (Firestore + local state)
    func add(_ cafe: Cafe) {
        guard let id = cafe.id, !savedIDs.contains(id) else { return }

        liked.append(cafe)
        savedIDs.append(id)

        AuthManager().addSavedCafeID(id) { err in
            if let err {
                print("addSavedCafeID error:", err.localizedDescription)
                return
            }

            // optional: update simple “trending” fields on cafe
            let db = Firestore.firestore()
            let cafeRef = db.collection("cafes").document(id)
            let now = Timestamp(date: Date())

            cafeRef.updateData(["lastSaveTimestamps": FieldValue.arrayUnion([now])]) { error in
                if let error {
                    print("Trending update error:", error); return
                }
                cafeRef.getDocument { snapshot, _ in
                    guard let snapshot, snapshot.exists,
                          var timestamps = snapshot.data()?["lastSaveTimestamps"] as? [Timestamp] else { return }

                    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                    timestamps = timestamps.filter { $0.dateValue() >= sevenDaysAgo }

                    cafeRef.updateData([
                        "lastSaveTimestamps": timestamps,
                        "savesLast7Days": timestamps.count
                    ])
                }
            }
        }
    }

    //completely unsave a cafe
    /// Removes from liked + folders (local + SwiftData) and Firestore “saved”
    func removeCompletely(_ cafe: Cafe) {
        guard let cafeID = cafe.id else { return }

        // local in-memory
        liked.removeAll { $0.id == cafeID }
        savedIDs.removeAll { $0 == cafeID }
        for i in folders.indices {
            folders[i].cafes.removeAll { $0.id == cafeID }
        }

        // SwiftData: delete any folder refs for this cafe
        guard let ctx = modelContext,
              let uid = Auth.auth().currentUser?.uid else { return }

        let all = (try? ctx.fetch(
            FetchDescriptor<FolderSD>(predicate: #Predicate { $0.ownerUID == uid })
        )) ?? []

        for f in all {
            for r in f.cafeRefs.filter({ $0.cafeID == cafeID }) {
                ctx.delete(r)
            }
            f.cafeRefs.removeAll { $0.cafeID == cafeID }
        }
        try? ctx.save()

        // Firestore: remove from saved list
        AuthManager().removeSavedCafeID(cafeID) { err in
            if let err { print("removeSavedCafeID error:", err.localizedDescription) }
        }
    }

    /// Remove all cafes from saved (folders auto-cleaned via removeCompletely)
    func removeAll() {
        let cafes = liked
        for c in cafes { removeCompletely(c) }
    }

    /// Remove a cafe only from a specific folder
    func removeCafe(_ cafe: Cafe, fromFolderID folderID: String) {
        // in-memory
        if let i = folders.firstIndex(where: { $0.id == folderID }) {
            folders[i].cafes.removeAll { $0.id == cafe.id }
        }

        // SwiftData
        guard let ctx = modelContext,
              let uid = Auth.auth().currentUser?.uid else { return }

        if let f = try? fetchFolderSD(by: folderID, ownerUID: uid, ctx: ctx),
           let ref = f.cafeRefs.first(where: { $0.cafeID == cafe.id }) {
            ctx.delete(ref)
            if let idx = f.cafeRefs.firstIndex(of: ref) { f.cafeRefs.remove(at: idx) }
            try? ctx.save()
        }
    }

    // MARK: - Reloads

    /// Force refresh from Firestore + SwiftData
    func forceReloadFromRemote() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()

            let ids = (doc.data()?["savedCafes"] as? [String]) ?? []
            self.savedIDs = ids

            await loadLikedFromFirestore(ids: ids)
            await loadFoldersFromSwiftData()
        } catch {
            print("forceReloadFromRemote error:", error.localizedDescription)
        }
    }

    /// Rebuild folders[] from SwiftData and fetch associated cafes
    func loadFoldersFromSwiftData() async {
        guard let ctx = modelContext,
              let uid = Auth.auth().currentUser?.uid else { return }

        let descriptor = FetchDescriptor<FolderSD>(
            predicate: #Predicate { $0.ownerUID == uid },
            sortBy: [SortDescriptor(\.name)]
        )

        let sdFolders = (try? ctx.fetch(descriptor)) ?? []
        var out: [SavedFolder] = []

        for f in sdFolders {
            let ids = f.cafeRefs.map(\.cafeID)
            let map = await fetchCafes(by: ids) // id -> Cafe
            out.append(
                SavedFolder(id: f.id, name: f.name, cafes: ids.compactMap { map[$0] })
            )
        }

        folders = out
    }

    // MARK: - Helpers

    private func fetchFolderSD(by id: String, ownerUID: String, ctx: ModelContext) throws -> FolderSD? {
        let descriptor = FetchDescriptor<FolderSD>(
            predicate: #Predicate { $0.id == id && $0.ownerUID == ownerUID }
        )
        return try ctx.fetch(descriptor).first
    }

    // split array into chunks (Firestore “in” query limit helper)
    private func chunk<T>(_ a: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [a] }
        var out: [[T]] = []
        var i = 0
        while i < a.count {
            let j = min(i + size, a.count)
            out.append(Array(a[i..<j]))
            i = j
        }
        return out
    }

    // keep the liked[] order equal to savedIDs order
    private func setLikedKeepingOrder(ids: [String], map: [String: Cafe]) {
        liked = ids.compactMap { map[$0] }
    }

    // decode Cafe from Firestore document
    private func decodeCafe(_ d: DocumentSnapshot) -> Cafe? {
        let m = d.data() ?? [:]
        return Cafe(
            id: d.documentID,
            name: (m["name"] as? String) ?? "Unknown",
            imageUrl: m["imageUrl"] as? String,
            amenities: m["amenities"] as? [String],
            createdAt: (m["createdAt"] as? Timestamp)?.dateValue(),
            address: m["address"] as? String,
            latitude: (m["latitude"] as? NSNumber)?.doubleValue,
            longitude: (m["longitude"] as? NSNumber)?.doubleValue,
            rating: (m["rating"] as? NSNumber)?.doubleValue,
            imageURLs: (m["imageURLs"] as? [String])?.compactMap(URL.init(string:)),
            specials: [],
            recents: m["recents"] as? [String],
            specialsIDs: (m["specialsIDs"] as? [String]) ?? (m["specials"] as? [String]) ?? []
        )
    }

    // fetch cafes in small groups by IDs (Firestore “in” query)
    private func fetchCafes(by ids: [String]) async -> [String: Cafe] {
        guard !ids.isEmpty else { return [:] }

        let db = Firestore.firestore()
        var map: [String: Cafe] = [:]

        for group in chunk(ids, size: 10) {
            do {
                let snap = try await db.collection("cafes")
                    .whereField(FieldPath.documentID(), in: group)
                    .getDocuments()

                for d in snap.documents {
                    if let c = decodeCafe(d) { map[d.documentID] = c }
                }
            } catch {
                print("fetchCafes(by:) error:", error.localizedDescription)
            }
        }
        return map
    }

    /// Refresh liked[] from Firestore using savedIDs
    private func loadLikedFromFirestore(ids: [String]) async {
        let map = await fetchCafes(by: ids)
        setLikedKeepingOrder(ids: ids, map: map)
    }
}
