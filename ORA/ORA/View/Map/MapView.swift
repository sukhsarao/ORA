import SwiftUI
import MapKit

/// Main map screen:
/// - We show only **Pinned (red)** and **Trending (blue)** cafes on the map.
/// - We let the user draw routes to a single cafe or a group (Nearest / Pinned / Trending).
/// - Tapping a cafe (pin or card) draws the route **and** opens the CafePageView.
struct MapView: View {
    // Theme + data
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var cafeVM = CafeViewModel()
    
    // Our shared, app wide location manager..
    @ObservedObject private var loc = SharedLocationManager.shared

    // UI state
    @State private var searchText = ""
    @State private var openCafe: Cafe? = nil
    @State private var routedCafeIDs: Set<String> = []     // which cafes we’re drawing routes for
    @State private var transportMode: TransportMode = .walking
    @State private var showSettings = false

    // How many trending cafrs we show in the strip
    private let trendingCount = 4

    var body: some View {
        NavigationStack {
            ZStack {
                ORABackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ORAHeader(onSettings: { showSettings = true })
                        searchBar

                        // Map shows only pinned + trending cafes (union)
                        MKMapRepresentable(
                            cafes: .constant(displayCafes),
                            pinnedIDs: Set(pinnedCafes.compactMap { $0.id }),
                            trendingIDs: Set(trendingCafes.compactMap { $0.id }),
                            routedCafeIDs: $routedCafeIDs,
                            transport: transportMode,
                            onTapCafe: { cafe in openCafe = cafe }, // tap pin -> open details
                            userLocation: loc.currentLocation       // used for distance + routes
                        )
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(line(scheme), lineWidth: 1))
                        .shadow(color: subtleShadow(scheme), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)

                        // Route controls (Nearest / Pinned / Trending / Clear)
                        controlsCard

                        // Trending cards (bigger) with extra bottom space
                        trendingStrip
                            .padding(.bottom, 30)

                        // Gentle hint when nothing pinned yet
                        if pinnedCafes.isEmpty {
                            Text("No pinned cafes yet tap the pin on a cafe to add one.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        NavigationStack {
                            SettingsView(themeManager: theme)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .onAppear {
                // We fetch cafe data and ask for location permissions right away
                cafeVM.fetchCafes()
                loc.requestPermissionIfNeeded()
                loc.requestLocation()
            }
            // Pushing detail screen when `openCafe` changes
            .navigationDestination(item: $openCafe) { cafe in
                CafePageView(cafeId: cafe.id ?? "", cafeTitle: cafe.name)
            }
        }
    }

    // MARK: Search Bar
    /// We keep this simple: search by name, on Return we open the cafe and draw the route.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

            TextField("Search cafes...", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { searchAndOpen() }

            // Quick clear button
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill(scheme)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(line(scheme), lineWidth: 1))
        .shadow(color: subtleShadow(scheme), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
    }

    // MARK: Controls
    /// Our routing shortcuts:
    /// - Nearest: route only to the closest *visible* cafe
    /// - Pinned: route to all pinned cafes
    /// - Trending: route to all trending cafes
    /// - Clear: remove all routes
    private var controlsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Routes").font(.caption.weight(.semibold))
                Spacer()
                // Walk/Drive toggle
                Picker("", selection: $transportMode) {
                    ForEach(TransportMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 150)
            }

            HStack(spacing: 6) {
                // NEAREST: clear others, keep only nearest visible cafe
                Button {
                    if let nearest = nearestVisibleCafe(), let id = nearest.id {
                        routedCafeIDs = [id]
                        openCafe = nearest
                    } else {
                        routedCafeIDs = []
                    }
                } label: { Label("Nearest", systemImage: "scope") }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // PINNED: clear others, route to pinned cafes only
                Button {
                    routedCafeIDs = Set(pinnedCafes.compactMap { $0.id })
                } label: { Label("Pinned", systemImage: "mappin") }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // TRENDING: clear others, route to trending cafes only
                Button {
                    routedCafeIDs = Set(trendingCafes.compactMap { $0.id })
                } label: { Label("Trending", systemImage: "flame") }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // CLEAR: remove all routes
                Button(role: .destructive) {
                    routedCafeIDs.removeAll()
                } label: { Label("Clear", systemImage: "trash") }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .font(.caption2)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(line(scheme), lineWidth: 1))
        .shadow(color: subtleShadow(scheme), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Trending Strip (bigger cards)
    /// Clean, tappable cards:
    /// - Tap = draw route to that single cafe and open detail.
    /// - We show distance using your global helper (if we have location).
    private var trendingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trending nearby")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color("Primary"))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(trendingCafes) { cafe in
                        VStack(alignment: .leading, spacing: 6) {
                            // Photo (or soft placeholder)
                            ZStack {
                                if let url = cafe.imageURLs?.first {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty: Color.gray.opacity(0.12)
                                        case .success(let img): img.resizable().scaledToFill()
                                        case .failure: Color.gray.opacity(0.12)
                                        @unknown default: Color.gray.opacity(0.12)
                                        }
                                    }
                                } else {
                                    Color.gray.opacity(0.12)
                                }
                            }
                            .frame(width: 164, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Name
                            Text(cafe.name)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color("Primary"))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            // Distance
                            if let dist = distanceText(for: cafe) {
                                Text(dist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 164, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Single route behavior: we set only this cafe’s id
                            if let id = cafe.id { routedCafeIDs = [id] }
                            openCafe = cafe
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(chipFill(scheme)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(line(scheme), lineWidth: 1))
                        .shadow(color: subtleShadow(scheme), radius: 4, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // Helpers

    /// Search by name, open the cafe, and draw a route to it.
    private func searchAndOpen() {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        if let cafe = cafeVM.cafes.first(where: { $0.name.localizedCaseInsensitiveContains(term) }) {
            if let id = cafe.id { routedCafeIDs = [id] }
            openCafe = cafe
        }
    }

    /// Current user's pinned cafes (from AuthManager).
    private var pinnedCafes: [Cafe] {
        let pinnedIDs = authManager.currentUser?.pinnedCafes ?? []
        return cafeVM.cafes.filter { cafe in
            guard let id = cafe.id else { return false }
            return pinnedIDs.contains(id)
        }
    }

    /// Trending cafes
    private var trendingCafes: [Cafe] {
        CafeUtils.getTrendingCafes(from: cafeVM.cafes, count: trendingCount)
    }

    /// Only show **Pinned ∪ Trending** on the map (we keep the map focused).
    private var displayCafes: [Cafe] {
        let ids = Set(pinnedCafes.compactMap { $0.id } + trendingCafes.compactMap { $0.id })
        return cafeVM.cafes.filter { cafe in
            guard let id = cafe.id else { return false }
            return ids.contains(id)
        }
    }

    /// Turn a cafe’s coords into a friendly distance text
    private func distanceText(for cafe: Cafe) -> String? {
        guard let lat = cafe.latitude, let lon = cafe.longitude else { return nil }
        let cafeLoc = CLLocation(latitude: lat, longitude: lon)
        return distanceString(from: loc.currentLocation, to: cafeLoc)
    }

    /// We find the nearest cafe among the ones we actually show on the map.
    private func nearestVisibleCafe() -> Cafe? {
        guard let u = loc.currentLocation else { return nil }
        let visible = displayCafes.compactMap { c -> (Cafe, CLLocation)? in
            guard let lat = c.latitude, let lon = c.longitude else { return nil }
            return (c, CLLocation(latitude: lat, longitude: lon))
        }
        return visible.min { pairA, pairB in
            u.distance(from: pairA.1) < u.distance(from: pairB.1)
        }?.0
    }
}
