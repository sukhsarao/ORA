import Foundation
import FirebaseFirestore

/// # SearchLogic
///
/// Stateless helpers for:
/// - **Firestore queries** (menu items via `collectionGroup("menus")`, cafe documents by ID)
/// - **Parsing** (prices, normalization)
/// - **(De)serialization** between `Row` and `RowCodable` used by snapshots
///
/// ## Firestore notes
/// - `collectionGroup("menus")` with `.order(by: "name")` requires an index on `name`.
///   If Firestore asks for an index URL in logs, create it once in the console.
/// - The `in` operator supports up to **10** IDs per query; this is why `fetchCafes` batches by 10.
/// - Sort and range filters must reference the **same** field (we use `name` with `start(at:)/end(at:)`).
///
///
/// ## Locale & normalization
/// - `normalize(_:)` lowercases, strips diacritics and non-alphanumerics so you can match
///   “Café Mocha” with “cafe mocha”.
enum SearchLogic {
    // MARK: Firestore

    /// Fetches menu documents whose `name` starts with `prefix` (case-sensitive on server side),
    /// then you can apply your own client-side normalization.
    ///
    /// - Parameters:
    ///   - db: Firestore instance.
    ///   - prefix: Leading text to probe (`"Latte"` -> `"Latte\u{f8ff}"`).
    ///   - limit: Max documents to return.
    /// - Returns: Array of `MenuJoin` (decoded menu item + parent cafe id + path).
    static func fetchMenus(db: Firestore, prefix: String, limit: Int) async throws -> [MenuJoin] {
        // Firestore trick: end bound with "\u{f8ff}" to include all strings that start with `prefix`
        let end = prefix + "\u{f8ff}"

        // Query every subcollection named "menus" across all cafes.
        // We sort by the "name" field so start/end bounds work.
        let snap = try await db.collectionGroup("menus")
            .order(by: "name")
            .start(at: [prefix])   // lower bound: name >= prefix
            .end(at: [end])        // upper bound: name <= prefix+\u{f8ff}
            .limit(to: limit)      // safety cap
            .getDocuments()

        // Convert Firestore docs -> MenuJoin safely.
        return snap.documents.compactMap { doc in
            let data = doc.data()

            // `name` is mandatory for our UI rows; skip if missing/empty.
            guard let name = anyToString(data["name"]), !name.isEmpty else {
                return nil
            }

            // Build a tolerant menu item:
            // - anyToString handles String OR Number
            // - sizesMapToStringDict normalises mixed-type maps to [String:String]
            let item = MenuItemDecodable(
                name: name,
                imageUrl: anyToString(data["imageUrl"]),
                description: anyToString(data["description"]),
                price: anyToString(data["price"]),
                sizes: sizesMapToStringDict(data["sizes"]),
                type: anyToString(data["type"])
            )

            // Get the parent cafe id: .../cafes/{cafeId}/menus/{menuId}
            let cafeId = doc.reference.parent.parent?.documentID

            // Path included for debugging.
            return MenuJoin(item: item, cafeId: cafeId, path: doc.reference.path)
        }
    }

    /// Broader probe: fetch menus for a single leading character (e.g., "c").
    static func fetchByLeading(db: Firestore, leading: String, limit: Int) async throws -> [MenuJoin] {
        // Same prefix range trick but for a single letter.
        let end = leading + "\u{f8ff}"

        let snap = try await db.collectionGroup("menus")
            .order(by: "name")
            .start(at: [leading])
            .end(at: [end])
            .limit(to: limit)
            .getDocuments()

        return snap.documents.compactMap { doc in
            let data = doc.data()

            // Require a valid name otherwise just skip
            guard let name = anyToString(data["name"]), !name.isEmpty else {
                return nil
            }

            // Tolerant field extraction keeps us resilient to Firestore
            let item = MenuItemDecodable(
                name: name,
                imageUrl: anyToString(data["imageUrl"]),
                description: anyToString(data["description"]),
                price: anyToString(data["price"]),
                sizes: sizesMapToStringDict(data["sizes"]),
                type: anyToString(data["type"])
            )

            // Walk up from .../menus/{menuId} to its parent cafe doc id.(firebase collection path)
            let cafeId = doc.reference.parent.parent?.documentID

            return MenuJoin(item: item, cafeId: cafeId, path: doc.reference.path)
        }
    }

    /// Batch-fetch minimal cafe info used for UI rows.
    ///
    /// Firestore’s `in` filter supports up to **10** IDs per request this method batches accordingly.
    ///
    /// - Parameters:
    ///   - db: Firestore instance.
    ///   - ids: Cafe document IDs.
    /// - Returns: Map of cafeId → `CafeLite`.
    static func fetchCafes(db: Firestore, ids: [String]) async throws -> [String: Cafe] {
        guard !ids.isEmpty else { return [:] }
        var out: [String: Cafe] = [:]

        let step = 10  // Firestore "in" max
        var i = 0
        while i < ids.count {
            let j = min(i + step, ids.count)
            let chunk = Array(ids[i..<j])

            let snap = try await db.collection("cafes")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for d in snap.documents {
                let data = d.data()
                out[d.documentID] = Cafe(
                    name: (data["name"] as? String) ?? "Cafe",
                    imageUrl: data["imageUrl"] as? String,
                    address: data["address"] as? String,
                    rating: (data["rating"] as? Double)
                )
            }
            i = j
        }
        return out
    }

    // MARK:utils

    /// Returns the **lowest** price from either `sizes` map or flat `price` field.
    static func lowestPrice(from item: MenuItemDecodable) -> Double? {
        if let sizes = item.sizes, !sizes.isEmpty {
            return sizes.values.compactMap(parsePrice).min()
        }
        if let p = item.price { return parsePrice(p) }
        return nil
    }

    /// Parses a price string like `"$5.50"`, `"5,50"`, `"A$4.20"`.
    /// Strips currency symbols/spaces and normalizes commas → dots when plausible.
    static func parsePrice(_ raw: String) -> Double? {
        // Trim & strip currency symbols
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove common currency symbols (A$, $, £, €, etc.) and any spaces
        t = t.replacingOccurrences(of: "A$", with: "", options: .caseInsensitive)
             .replacingOccurrences(of: "$",  with: "")
             .replacingOccurrences(of: "€",  with: "")
             .replacingOccurrences(of: "£",  with: "")
             .replacingOccurrences(of: "¥",  with: "")
             .replacingOccurrences(of: " ",  with: "")

        // Heuristic: if there is a comma and no dot, treat comma as decimal separator
        if t.contains(",") && !t.contains(".") {
            t = t.replacingOccurrences(of: ",", with: ".")
        } else {
            // Otherwise remove grouping commas
            t = t.replacingOccurrences(of: ",", with: "")
        }
        return Double(t)
    }

    /// Normalizes text for client-side matching:
    /// - lowercases with current locale,
    /// - removes diacritics (e.g., “Café” -> “Cafe”),
    /// - strips non-alphanumerics.
    static func normalize(_ s: String) -> String {
        let lowered = s.lowercased(with: .current)
        let folded = lowered.folding(options: .diacriticInsensitive, locale: .current)
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
    
    // MARK: Paged sweep to avoid truncation when there are many names for a letter
    static func fetchByLeadingPaged(
        db: Firestore,
        leading: String,
        pageSize: Int = 300,
        maxDocs: Int = 2400,
        stopWhenFound: Int? = nil,
        matches: @escaping (MenuJoin) -> Bool
    ) async throws -> [MenuJoin] {
        let end = leading + "\u{f8ff}"
        var out: [MenuJoin] = []
        var last: DocumentSnapshot? = nil
        var fetched = 0

        while fetched < maxDocs {
            var q = db.collectionGroup("menus")
                .order(by: "name")
                .start(at: [leading])
                .end(at: [end])
                .limit(to: pageSize)

            if let last = last { q = q.start(afterDocument: last) }

            let snap = try await q.getDocuments()
            if snap.documents.isEmpty { break }

            for doc in snap.documents {
                fetched += 1
                guard let json = try? JSONSerialization.data(withJSONObject: doc.data()),
                      let item = try? JSONDecoder().decode(MenuItemDecodable.self, from: json) else { continue }
                let cafeId = doc.reference.parent.parent?.documentID
                let join = MenuJoin(item: item, cafeId: cafeId, path: doc.reference.path)

                // Only keep docs that pass the client-side matcher
                if matches(join) { out.append(join) }
            }

            last = snap.documents.last

            if let need = stopWhenFound, out.count >= need { break }
            if snap.documents.count < pageSize { break } // no more pages
        }
        return out
    }
    
    
    // MARK: - Codable bridge

    /// Convert UI rows to a compact codable form for snapshot storage.
    static func toCodable(_ rows: [Row]) -> [RowCodable] {
        rows.map { r in
            RowCodable(
                cafeId: r.cafeId,
                itemName: r.itemName,
                price: r.price,
                cafeName: r.cafeName,
                imageURL: r.imageURL,
                cafeAddress: r.cafeAddress,
                cafeRating: r.cafeRating
            )
        }
    }

    /// Rebuild UI rows from their codable snapshot form.
    static func fromCodable(_ rows: [RowCodable]) -> [Row] {
        rows.map { r in
            Row(
                cafeId: r.cafeId,
                itemName: r.itemName,
                price: r.price,
                cafeName: r.cafeName,
                imageURL: r.imageURL,
                cafeAddress: r.cafeAddress,
                cafeRating: r.cafeRating
            )
        }
    }

}




// These helpers make decoding Firestore fields **forgiving**.
// Why? In Firestore, the same field can show up as String or Number
// (e.g. "5.50" vs 5.5). If we decode strictly, we drop those docs.
// With these, we normalize values so your search never silently skips items.

/// Tries to turn "whatever Firestore gave us" into a String.
/// - Accepts: String or Number (NSNumber/Int/Double).
/// - Use case: fields like `name`, `imageUrl`, `price` that might be String,
///   or sometimes a Number saved by mistake.
/// - Returns nil if it can't make sense of the value.
private func anyToString(_ any: Any?) -> String? {
    switch any {
    case let s as String:
        // Already a string → good to go.
        return s
    case let n as NSNumber:
        // Price/rating/etc may arrive as a number; stringify it.
        return n.stringValue
    default:
        // Something else (Timestamp/GeoPoint/etc) → we don’t try to stringify it.
        return nil
    }
}

/// Tries to turn a Firestore value into a Double (for prices/ratings).
/// - Accepts: Double, Int/NSNumber, or a price String like "A$4.20" or "5,50".
/// - Cleans currency symbols and commas so "$5,500.00" -> 5500.0.
/// - Returns nil if it can't be parsed.
private func anyToDouble(_ any: Any?) -> Double? {
    // If it's already numeric, just convert.
    if let d = any as? Double { return d }
    if let i = any as? Int { return Double(i) }
    if let n = any as? NSNumber { return n.doubleValue }

    // If it's a string, scrub currency symbols/spaces and normalize separators.
    if let s = any as? String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip common currency symbols like A$, $,nd spaces.
        t = t.replacingOccurrences(of: "A$", with: "", options: .caseInsensitive)
             .replacingOccurrences(of: "$",  with: "")
             .replacingOccurrences(of: " ",  with: "")

        // Handle "5,50" -> "5.50".
        if t.contains(",") && !t.contains(".") {
            t = t.replacingOccurrences(of: ",", with: ".")
        } else {
            // Otherwise commas are likely thousands separators: "5,500" -> "5500".
            t = t.replacingOccurrences(of: ",", with: "")
        }
        return Double(t)
    }

    // Not a typealso  we handle.
    return nil
}

/// Converts a Firestore map like `sizes` into [String:String].
/// - Accepts: values that are String ("5.0") or Number (5.0).
/// - Goal: unify everything to String so your existing parsing stays simple.
/// - Example: {"Small": 4.5, "Large": "6.0"} -> ["Small": "4.5", "Large": "6.0"]
private func sizesMapToStringDict(_ any: Any?) -> [String:String]? {
    guard let dict = any as? [String:Any] else { return nil }

    var out: [String:String] = [:]
    for (k, v) in dict {
        // If value is a String, keep it. If it's a Number, stringify it.
        if let s = anyToString(v) {
            out[k] = s
        } else if let d = anyToDouble(v) {
            out[k] = String(d)
        }
        // If it's neither, we quietly skip that entry instead of failing the whole doc.
    }
    return out
}
