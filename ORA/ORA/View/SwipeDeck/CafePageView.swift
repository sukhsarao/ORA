import SwiftUI
import FirebaseFirestore

/// Displays detailed information about a cafe, including hero images, specials, amenities, and saving/pinning functionality.
struct CafePageView: View {
    let cafeId: String                 // Firestore ID of the cafe
    let cafeTitle: String              // Fallback cafe title if data not loaded

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var auth: AuthManager
    @Environment(\.colorScheme) private var scheme

    @State private var cafe: CafeDoc?                  // Loaded cafe data
    @State private var specials: [CafeMenuItem] = []  // Special menu items
    @State private var isLoading = true               // Loading state
    @State private var errText: String?              // Error message

    @State private var showSettings = false
    @State private var tab: ORATab = .search

    @State private var heroURLs: [URL] = []          // Hero image URLs
    @State private var heroIndex: Int = 0
    @State private var unsplashURL: URL?             // Fallback Unsplash image

    @State private var goToMenu = false
    @State private var isSavedLocal: Bool? = nil     // Local override of saved state
    @State private var showSignInAlert = false
    @State private var heartBounce = false

    private var effectiveCafeID: String { cafe?.id ?? cafeId }
    private var isSaved: Bool {                        // Determines if cafe is saved
        if let override = isSavedLocal { return override }
        return auth.currentUser?.savedCafes.contains(effectiveCafeID) ?? false
    }

    private let placesManager = PlacesManager()       // Handles Google Places data

    // MARK: - UI Colors & Gradients
    private var screenBG: LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [AppColor.dark.opacity(1.0), AppColor.dark.opacity(0.94)],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [AppColor.circleOne.opacity(0.22),
                         AppColor.circleTwo.opacity(0.14),
                         Color(.systemBackground)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
    private var hairline: Color { scheme == .dark ? .white.opacity(0.06) : .black.opacity(0.06) }
    private var subtleShadow: Color { scheme == .dark ? .black.opacity(0.45) : .black.opacity(0.25) }
    private var fabDim: Color { scheme == .dark ? .black.opacity(0.72) : .black.opacity(0.65) }
    private var chipBackground: LinearGradient {
        if scheme == .dark {
            return LinearGradient(colors: [AppColor.circleOne, AppColor.circleTwo],
                                  startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [AppColor.circleOne.opacity(0.26),
                                           AppColor.circleTwo.opacity(0.18)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            screenBG.ignoresSafeArea()

            VStack(spacing: 0) {
                ORAHeader(onSettings: { showSettings = true }) // Show settings
                header
                ScrollView { mainContent }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
            }

            ORABottomBar(selection: $tab)
                .padding(.bottom, 3)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(themeManager: theme)
                    .environmentObject(auth)
            }
        }
        // Handling unsigned in user
        .overlay(loadingOverlay)
        .overlay(saveFAB, alignment: .bottomTrailing)
        .alert("Sign in required", isPresented: $showSignInAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need to be signed in to save cafés.")
        }
        .task { await load() }
        .onAppear { syncSavedState() }
        .onChange(of: auth.currentUser?.savedCafes) { _, _ in syncSavedState() }
        .onChange(of: cafe?.id) { _, _ in syncSavedState() }
    }
    
    // MARK: - Header
    private var header: some View {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.vertical, 8).padding(.horizontal, 4)
                }
                .buttonStyle(.plain)

                Spacer()

            }
            .padding(.horizontal, 16).padding(.top, 6)
        }

    // MARK: - Main content
    private var mainContent: some View {
        VStack(spacing: 18) {
            heroHeader
            VStack(spacing: 8) {
                Text(cafe?.name ?? cafeTitle)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColor.primary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Rating(rating: cafe?.rating, bgColor: AppColor.circleTwo.opacity(0.22), fgColor: AppColor.primary)
                    if !specials.isEmpty {
                        Text("|")
                        Label("\(specials.count) specials", systemImage: "flame.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            if let amenities = cafe?.amenities, !amenities.isEmpty {
                AmenityChips(amenities: amenities, background: chipBackground, hairline: hairline)
                    .padding(.horizontal, 16)
            }

            SpecialsStripGeneric(
                items: specials.map { DisplayItem(id: $0.id, name: $0.name, imageURL: $0.imageUrl.flatMap(URL.init(string:))) }
            ) { goToMenu = true }

            if let recents = cafe?.recents {
                RecentsStripGeneric(imageURLs: recents.compactMap(URL.init(string:)))
            }

            NavigationLink(destination: MenuView(cafeId: cafe?.id ?? cafeId, cafeTitle: cafe?.name ?? cafeTitle),
                           isActive: $goToMenu) { EmptyView() }.hidden()

            if let addr = cafe?.address, !addr.isEmpty {
                AddressBlock(address: addr,
                             isPinned: auth.currentUser?.pinnedCafes.contains(effectiveCafeID) ?? false) {
                    auth.togglePinnedCafe(cafeId: effectiveCafeID)
                }
            }

            Spacer(minLength: 24)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Hero Section
    private var heroHeader: some View {
        PhotoCarousel(source: .urls(heroURLs)) { heroIndex = $0 }
            .padding(.horizontal, 16)
            .overlay(
                LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.22)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .allowsHitTesting(false),
                alignment: .bottom
            )
    }

    private var loadingOverlay: some View {
        Group {
            if isLoading { ProgressView().tint(AppColor.primary) }
            else if let e = errText {
                VStack(spacing: 10) {
                    Text("Couldn’t load cafe").font(.headline)
                    Text(e).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.padding()
            }
        }
    }

    private var saveFAB: some View {
        SaveFAB(isSaved: isSaved,
                heartBounce: heartBounce,
                dim: fabDim,
                shadow: subtleShadow) { handleToggleSave() }
            .padding(.trailing, 18)
            .padding(.bottom, 72)
    }

    // MARK: - Load cafe data
    private func load() async {
        isLoading = true; errText = nil
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("cafes").document(cafeId).getDocument()
            guard snap.exists, let data = snap.data() else {
                throw NSError(domain: "CafeDetail", code: 404, userInfo: [NSLocalizedDescriptionKey: "Cafe not found"])
            }

            var c = CafeDoc.from(dict: data, id: snap.documentID)
            await MainActor.run { self.cafe = c }

            // Hero images
            var urls: [URL] = []
            if let s = c.imageUrl, let u = URL(string: s) { urls.append(u) }
            if let g = c.gallery { g.prefix(3).compactMap(URL.init).forEach { urls.append($0) } }
            urls = Array(Set(urls))  // remove duplicates
            await MainActor.run { self.heroURLs = urls; self.heroIndex = 0 }

            // Specials
            var specialItems: [CafeMenuItem] = []
            if let ids = c.specialsIDs {
                for id in ids {
                    if let subSnap = try? await db.collection("cafes").document(c.id).collection("menus").document(id).getDocument(),
                       let mapped = subSnap.data().flatMap({ CafeMenuItem.from(dict: $0, id: subSnap.documentID) }) {
                        specialItems.append(mapped)
                        continue
                    }
                    if let topSnap = try? await db.collection("menuItems").document(id).getDocument(),
                       let mapped = topSnap.data().flatMap({ CafeMenuItem.from(dict: $0, id: topSnap.documentID) }) {
                        specialItems.append(mapped)
                    }
                }
            }

            // Fetch place details from Google Places
            await withCheckedContinuation { cont in
                placesManager.fetchPlaceDetails(for: c.name) { info in
                    if let info {
                        if (c.address?.isEmpty ?? true), !info.address.isEmpty { c.address = info.address }
                        if c.rating == nil, let r = info.rating { c.rating = r }
                        if self.heroURLs.isEmpty, !info.photoURLs.isEmpty {
                            self.heroURLs = info.photoURLs
                            self.heroIndex = 0
                        }
                        c.latitude = c.latitude ?? info.latitude
                        c.longitude = c.longitude ?? info.longitude
                    }
                    cont.resume()
                }
            }

            // Unsplash fallback
            if self.heroURLs.isEmpty, let u = await UnsplashClient.shared.url(for: c.name) {
                await MainActor.run { self.unsplashURL = u }
            }

            await MainActor.run {
                self.cafe = c
                self.specials = specialItems
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.errText = error.localizedDescription; self.isLoading = false }
        }
    }

    // MARK: - Saved state handling
    private func syncSavedState() {
        let saved = auth.currentUser?.savedCafes.contains(effectiveCafeID) ?? false
        if isSavedLocal != saved { isSavedLocal = saved }
    }

    private func handleToggleSave() {
        guard auth.currentUser != nil else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showSignInAlert = true
            return
        }
        isSavedLocal = !isSaved
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        heartBounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { heartBounce = false }

        auth.toggleSavedCafe(cafeId: effectiveCafeID)
    }
}

// MARK: - Helper Views & Models

private struct SizeReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: RowWidthKey.self, value: proxy.size.width)
        }
    }
}

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Represents a cafe document fetched from Firestore
private struct CafeDoc {
    let id: String
    let name: String
    let imageUrl: String?
    let gallery: [String]?
    var rating: Double?
    let amenities: [String]?
    let recents: [String]?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var specialsIDs: [String]?

    static func from(dict: [String: Any], id: String) -> CafeDoc {
        CafeDoc(
            id: id,
            name: dict["name"] as? String ?? "Cafe",
            imageUrl: dict["imageUrl"] as? String,
            gallery: dict["gallery"] as? [String],
            rating: dict["rating"] as? Double,
            amenities: dict["amenities"] as? [String],
            recents: dict["recents"] as? [String],
            address: dict["address"] as? String,
            latitude: dict["latitude"] as? Double,
            longitude: dict["longitude"] as? Double,
            specialsIDs: dict["specials"] as? [String]
        )
    }
}

/// Represents a menu item, either from cafe subcollection or global menuItems
private struct CafeMenuItem: Identifiable {
    let id: String
    let name: String
    let imageUrl: String?

    static func from(dict: [String: Any], id: String) -> CafeMenuItem? {
        let name = dict["name"] as? String ?? "Item"
        return CafeMenuItem(id: id, name: name, imageUrl: dict["imageUrl"] as? String)
    }
}
