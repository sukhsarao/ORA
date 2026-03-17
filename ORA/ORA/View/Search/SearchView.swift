import SwiftUI
import FirebaseFirestore
import SwiftData

/// # SearchView
///
/// High-level search screen for menu items across cafes.
/// We manage:
/// - **Input state** (query, focus)
/// - **Network state** (loading, error)
/// - **Results list** + navigation
/// - **Recents** (loaded from SwiftData via `SearchStorage`)
///
/// We keep the UI predictable using a small `ViewState` enum.
struct SearchView: View {

    // MARK: - Environment

    /// SwiftData context for loading/saving recent snapshots.
    @Environment(\.modelContext) private var modelContext

    /// Tracks keyboard focus for the search field.
    @FocusState private var searchFocused: Bool

    /// For light/dark-aware drawing helpers.
    @Environment(\.colorScheme) private var scheme

    // MARK: - Screen State

    /// Text the user types into the search field.
    @State private var query = ""

    /// We flip this while we fetch from Firestore.
    @State private var isLoading = false

    /// Non-nil when the last search failed.
    @State private var errorText: String?

    /// Current search results to render.
    @State private var results: [Row] = []

    /// The query string that produced `results` (for the banner).
    @State private var cachedQueryTitle: String? = nil

    /// Whether we already ran at least one search.
    @State private var hasSearched: Bool = false

    /// Recents loaded from SwiftData (decoded rows).
    @State private var recents: [RecentItem] = []

    /// Recents filtered live while the user types.
    private var filteredRecents: [RecentItem] {
        guard !query.isEmpty else { return recents }
        return recents.filter { $0.query.localizedCaseInsensitiveContains(query) }
    }

    // MARK: View State Machine

    /// Simple states to keep the large switch tidy and easy to read.
    private enum ViewState {
        case shortcutsAndRecents
        case filteringRecents
        case idleShortcuts
        case results
        case emptyAfterSearch
        case error(String)
    }

    /// Derives the current UI state from our flags and values.
    private var viewState: ViewState {
        if let err = errorText, !isLoading, !(searchFocused && !query.isEmpty) { return .error(err) }
        if !results.isEmpty { return .results }
        if hasSearched { return .emptyAfterSearch }
        if searchFocused && query.isEmpty { return .shortcutsAndRecents }
        if searchFocused && !query.isEmpty { return .filteringRecents }
        return .idleShortcuts
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            SearchBar

            // Banner when showing cached/restored results
            if let title = cachedQueryTitle, !results.isEmpty, !isLoading, errorText == nil {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Showing results for “\(title)”").font(.footnote)
                    Spacer()
                    Button("Clear") {
                        results = []
                        cachedQueryTitle = nil
                    }
                    .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .accessibilityLabel("Showing results for \(title)")
            }

            contentContainer
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Load a few recents when the screen appears.
        .task { await loadRecents(limit: 5) }
        // If the user focuses the field again, refresh recents (cheap, local).
        .onChange(of: searchFocused) { _, focused in
            if focused { Task { await loadRecents(limit: 5) } }
        }
        // Keyboard toolbar with a “Done” to dismiss.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { searchFocused = false }
            }
        }
    }

    // MARK: - Actions

    /// Run the search and then dismiss the keyboard.
    func runAndDismissKeyboard() {
        Task {
            await runSearch()
            await MainActor.run { searchFocused = false }
        }
    }

    /// Reset to the inline shortcuts state.
    private func goBackToShortcuts() {
        query = ""
        results = []
        errorText = nil
        cachedQueryTitle = nil
        hasSearched = false
        searchFocused = true
        Task { await loadRecents(limit: 5) }
    }

    // MARK: - Search Bar

    /// The compact search field with a clear and a “Go” button.
    private var SearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

            TextField("Search menu items", text: $query)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { runAndDismissKeyboard() }

            if !query.isEmpty {
                Button { goBackToShortcuts() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear")
            }

            Button { runAndDismissKeyboard() } label: { Text("Go").bold() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(chipFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(line(scheme), lineWidth: 1)
        )
        .shadow(color: subtleShadow(scheme), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
        .accessibilityHint("Enter a menu item and press Go to search")
    }

    // MARK: - Content

    /// Main content area driven by `viewState`.
    private var contentContainer: some View {
        ZStack(alignment: .topLeading) {
            switch viewState {
            case .shortcutsAndRecents:
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !recents.isEmpty {
                            RecentSearchesSection(
                                items: recents,
                                onPick: { item in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    cachedQueryTitle = item.query
                                    results = item.rows
                                    hasSearched = true
                                    searchFocused = false
                                },
                                onClearAll: {
                                    clearAllRecents()
                                    recents.removeAll()
                                }
                            )
                        }

                        // Your custom shortcuts (popular queries, categories, etc.)
                        SearchShortcutsSection { picked in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            query = picked
                            runAndDismissKeyboard()
                        }
                        .padding(.top, recents.isEmpty ? 0 : 4)
                    }
                    .padding(.top, 4)
                }

            case .filteringRecents:
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !filteredRecents.isEmpty {
                            RecentSearchesSection(
                                items: filteredRecents,
                                onPick: { item in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    cachedQueryTitle = item.query
                                    results = item.rows
                                    hasSearched = true
                                    searchFocused = false
                                },
                                onClearAll: {
                                    clearAllRecents()
                                    recents.removeAll()
                                }
                            )
                        } else {
                            // Keeps layout steady when filter yields no matches.
                            Color.clear.frame(height: 1)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.top, 4)
                }

            case .idleShortcuts:
                SearchShortcutsSection { picked in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    query = picked
                    runAndDismissKeyboard()
                }

            case .results:
                // Results list with navigation to the cafe page.
                List(results) { r in
                    NavigationLink {
                        CafePageView(cafeId: r.cafeId, cafeTitle: r.cafeName)
                    } label: {
                        ResultRow(row: r)
                    }
                    .listRowInsets(.init(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(line(scheme))
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 72)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)

            case .emptyAfterSearch:
                // Helpful empty state with tips and a call-to-action.
                EmptyState(
                    title: "No matches found",
                    subtitle: "Try broader keywords or explore popular shortcuts.",
                    tips: ["Use shorter words", "Try a category like “frappe”", "Search by item name"],
                    primaryTitle: "Explore shortcuts",
                    onPrimary: { goBackToShortcuts() }
                )
                .padding(.top, 8)

            case .error(let err):
                // Friendly error with retry and a way back.
                ErrorView(
                    title: "Search failed",
                    message: err,
                    primary: ("Try again", { runAndDismissKeyboard() }),
                    secondary: ("Explore shortcuts", { goBackToShortcuts() })
                )
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .center) {
            if isLoading { ProgressView().scaleEffect(1.15) }
        }
        // We keep animations explicit; state flips are already clear.
        .animation(nil, value: searchFocused)
        .animation(nil, value: query)
        .animation(nil, value: results.count)
        .animation(nil, value: isLoading)
        .animation(nil, value: hasSearched)
    }
}

// MARK: Orchestration (Search + Storage)
// We coordinate calls to Firestore (via `SearchLogic`) and local cache (via `SearchStorage`).
private extension SearchView {

    /// Load most recent snapshots from SwiftData and publish to `recents`.
    func loadRecents(limit: Int = 5) async {
        let items = SearchStorage.loadRecents(modelContext: modelContext, limit: limit)
        await MainActor.run { self.recents = items }
    }

    /// Clear stored recents from SwiftData.
    func clearAllRecents() {
        SearchStorage.clearAllRecents(modelContext: modelContext)
    }

    /// main search pipeline:
    /// 1. Collect variants (case forms) of the query.
    /// 2. Fetch matching menus by prefix across the collection group.
    /// 3. if results are sparse, broaden with a “leading letter” sweep and client side filter.
    /// 4. Batch-load cafes for the unique IDs we found.
    /// 5. Build UI rows and dedupe by (cafeId + itemName).
    /// 6. then save a snapshot and refresh recents.
    func runSearch() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []; errorText = nil; cachedQueryTitle = nil; hasSearched = false
            return
        }

        hasSearched = true
        isLoading = true
        errorText = nil
        results = []
        cachedQueryTitle = nil

        do {
            let db = Firestore.firestore()

            // Create a few case variants to widen server-side prefix matches.
            let variants = Array(Set([term, term.lowercased(), term.uppercased(), term.capitalized]))
                .filter { !$0.isEmpty }

            // 1) Fetch menus for variants (in parallel).
            var all: [MenuJoin] = []
            try await withThrowingTaskGroup(of: [MenuJoin].self) { group in
                for v in variants {
                    group.addTask { try await SearchLogic.fetchMenus(db: db, prefix: v, limit: 40) }
                }
                for try await chunk in group { all.append(contentsOf: chunk) }
            }

            // 2) Deduplicate paths (same Firestore doc can arrive via multiple variants).
            var deduped = all.unique(by: { $0.path })

            // 3) If we have few, run a “leading char” sweep and client-filter.
            let normQuery = SearchLogic.normalize(term)
            if deduped.count < 6 {
                let tokens = term.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                var letterSet = Set<Character>()
                letterSet.formUnion(tokens.compactMap { $0.first })
                for ch in normQuery { letterSet.insert(ch) }
                let probeLetters = Array(letterSet).prefix(12)

                var sweep: [MenuJoin] = []
                try await withThrowingTaskGroup(of: [MenuJoin].self) { group in
                    for ch in probeLetters {
                        let s = String(ch)
                        group.addTask { try await SearchLogic.fetchByLeading(db: db, leading: s.lowercased(), limit: 200) }
                        group.addTask { try await SearchLogic.fetchByLeading(db: db, leading: s.uppercased(), limit: 200) }
                    }
                    for try await chunk in group { sweep.append(contentsOf: chunk) }
                }

                // Only keep new paths, then filter by our normalized query.
                let seenPaths = Set(deduped.map { $0.path })
                sweep = sweep.filter { !seenPaths.contains($0.path) }
                deduped.append(contentsOf: sweep)
                deduped = deduped.filter { SearchLogic.normalize($0.item.name).contains(normQuery) }
            }

            // 4) Fetch cafes referenced by the menu docs (batched by 10).
            let cafeIds = Array(Set(deduped.compactMap { $0.cafeId }))
            let cafeMap = try await SearchLogic.fetchCafes(db: db, ids: cafeIds)

            // 5) Build lightweight rows (with best effort image URL).
            var rows: [Row] = deduped.compactMap { j in
                guard let cid = j.cafeId, let cafe = cafeMap[cid] else { return nil }
                let price = SearchLogic.lowestPrice(from: j.item)
                let imageURL: URL? = {
                    if let s = j.item.imageUrl, !s.isEmpty { return URL(string: s) }
                    if let s = cafe.imageUrl, !s.isEmpty { return URL(string: s) }
                    return nil
                }()
                return Row(
                    cafeId: cid,
                    itemName: j.item.name,
                    price: price,
                    cafeName: cafe.name,
                    imageURL: imageURL,
                    cafeAddress: cafe.address,
                    cafeRating: cafe.rating
                )
            }

            // 6) Final UI de duplication by (cafeId|itemName).
            rows = rows.unique(by: { "\($0.cafeId)|\($0.itemName.lowercased())" })

            // Publish the results and remember the query used.
            await MainActor.run {
                self.results = rows
                self.isLoading = false
                self.cachedQueryTitle = term
            }

            // Save a local snapshot and refresh recents in the background.
            SearchStorage.saveSnapshot(modelContext: modelContext, query: term, rows: rows, keepMostRecent: 5)
            await loadRecents(limit: 5)

        } catch {
            await MainActor.run {
                self.errorText = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: Small UI Bits

/// Simple badge for counts (e.g., “3 items”).
struct CountBadge: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(chipFill(scheme))
            .overlay(Capsule().stroke(line(scheme), lineWidth: 1))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
}

// MARK: Utilities

/// Generic de duplication by a derived key.
/// We keep the first time we see each key and drop the rest.
extension Sequence {
    func unique<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        var out: [Element] = []
        for el in self {
            let k = key(el)
            if seen.insert(k).inserted { out.append(el) }
        }
        return out
    }
}
