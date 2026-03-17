import SwiftUI

/// A SwiftUI view that displays a cafe image card, optionally showing the cafe title
/// and highlighting the border if selected or featured.
struct CafeImageCard: View {
    /// The `Cafe` model containing name and image data
    let cafe: Cafe
    
    /// Corner radius for the image card (default: 12)
    var corner: Double = 12
    
    /// Whether to overlay the cafe title text at the bottom
    var showTitle: Bool = false
    
    /// Whether to visually highlight the card (e.g. selected state)
    var highlight: Bool = false

    // MARK: - State & Managers
    
    /// A fallback photo URL retrieved from Places API
    @State private var placeURL: URL?
    
    /// Handles fetching place details and photos from Google Places
    private let places = PlacesManager()

    // MARK: - Image URL Resolution
    
    /// Primary (baked) URL — usually pre-stored in the Cafe record
    private var bakedURL: URL? {
        cafe.imageURLs?.first ?? cafe.imageUrl.flatMap(URL.init(string:))
    }
    
    /// The actual URL to be displayed — baked first, then fallback to Places
    private var displayURL: URL? {
        bakedURL ?? placeURL
    }

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // MARK: - Async Image Loader
            AsyncImage(url: displayURL, transaction: .init(animation: .easeInOut)) { phase in
                switch phase {
                case .empty:
                    // While loading, show subtle background and spinner
                    ZStack {
                        Color.secondary.opacity(0.06)
                        ProgressView()
                    }
                case .success(let img):
                    // Successfully loaded image
                    img
                        .resizable()
                        .clipped()
                case .failure:
                    // Image failed to load — show placeholder icon
                    ZStack {
                        Color.secondary.opacity(0.08)
                        Image(systemName: "photo")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    // Defensive fallback for any unknown AsyncImage phase
                    ZStack {
                        Color.secondary.opacity(0.06)
                        ProgressView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            // MARK: - Title Overlay (if enabled)
            if showTitle {
                // Gradient overlay to improve text legibility
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)

                // Cafe name text
                Text(cafe.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        // MARK: - Highlight Border
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(highlight ? Color.accentColor : .clear,
                        lineWidth: highlight ? 3 : 0)
        )
        // Makes the shape tappable even beyond visible bounds
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        // Accessibility label for screen readers
        .accessibilityLabel(cafe.name)
        
        // MARK: - Image Fetch Task
        .task(id: cafe.id ?? cafe.name) {
            // Only attempt Places fetch if no baked URL exists
            guard bakedURL == nil else { return }

            // Cache key derived from cafe name
            let key = cafe.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use cached place photo if available
            if let cached = PlacePhotoCache.shared[key] {
                placeURL = cached
                return
            }

            // Fetch place details (async continuation pattern)
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                places.fetchPlaceDetails(for: cafe.name) { info in
                    // Store photo URL if found and update UI on main actor
                    if let u = info?.photoURLs.first {
                        PlacePhotoCache.shared[key] = u
                        Task { @MainActor in placeURL = u }
                    }
                    cont.resume()
                }
            }
        }
    }
}
