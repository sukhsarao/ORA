import SwiftUI
import SwiftData

/// SwiftData-only model we use to store recent search snapshots.
/// We keep one row per unique `query`, plus the encoded results and a timestamp.
@Model
final class SearchSnapshot {
    /// Unique key for the snapshot (one snapshot per query).
    @Attribute(.unique) var query: String

    /// When we saved/updated this snapshot.
    var createdAt: Date

    /// Encoded `[RowCodable]` data for the results.
    var rowsData: Data

    init(query: String, rowsData: Data, createdAt: Date = .init()) {
        self.query = query
        self.rowsData = rowsData
        self.createdAt = createdAt
    }
}
