import Foundation
import SwiftData

/// Storage helpers for saving and loading recent search snapshots with SwiftData.
enum SearchStorage {
    /// Save (or update) a snapshot for a query.
    /// We also keep only the most recent `limit` snapshots.
    static func saveSnapshot(modelContext: ModelContext, query: String, rows: [Row], keepMostRecent limit: Int = 5) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(SearchLogic.toCodable(rows)) else { return }

        //by unique `query`
        if let existing = try? modelContext.fetch(
            FetchDescriptor<SearchSnapshot>(predicate: #Predicate { $0.query == query })
        ).first {
            existing.rowsData = data
            existing.createdAt = Date()
        } else {
            modelContext.insert(SearchSnapshot(query: query, rowsData: data))
        }

        // Keep only the newest `limit` snapshots
        if let all = try? modelContext.fetch(
            FetchDescriptor<SearchSnapshot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        ), all.count > limit {
            for extra in all.dropFirst(limit) {
                modelContext.delete(extra)
            }
        }

        try? modelContext.save()
    }

    /// Load recent snapshots (deduped by query), newest first.
    static func loadRecents(modelContext: ModelContext, limit: Int = 5) -> [RecentItem] {
        let snaps = (try? modelContext.fetch(
            FetchDescriptor<SearchSnapshot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        let decoder = JSONDecoder()

        // We dedupe by `query`, take the newest `limit`, and decode rows
        let items: [RecentItem] = snaps
            .unique(by: { $0.query })
            .prefix(limit)
            .compactMap { s in
                guard let rows = try? decoder.decode([RowCodable].self, from: s.rowsData) else { return nil }
                return RecentItem(query: s.query, rows: SearchLogic.fromCodable(rows), when: s.createdAt)
            }

        return items
    }

    /// Remove all saved recents.
    static func clearAllRecents(modelContext: ModelContext) {
        if let all = try? modelContext.fetch(FetchDescriptor<SearchSnapshot>()) {
            for s in all { modelContext.delete(s) }
            try? modelContext.save()
        }
    }
}
