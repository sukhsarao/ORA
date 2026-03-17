import SwiftUI

// MARK: - Generic lightweight DTO
/// Represents a simple displayable item with an optional image.
public struct DisplayItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let imageURL: URL?

    public init(id: String, name: String, imageURL: URL?) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
    }
}

// MARK: - Dashes indicator
/// Horizontal dashed indicator, useful for carousels.
/// Highlights the current index and allows tapping on each dash.
public struct DashesIndicator: View {
    public let count: Int
    public let index: Int
    public var onTap: (Int) -> Void = { _ in }

    public var height: CGFloat = 6
    public var spacing: CGFloat = 16
    public var sideInset: CGFloat = 2
    public var activeFill: Color   = AppColor.primary.opacity(0.9)
    public var inactiveFill: Color = AppColor.primary.opacity(0.35)
    public var showStroke: Bool = true
    public var strokeColor: Color = .black.opacity(0.15)
    public var strokeWidth: CGFloat = 0.5
    public var cornerRadius: CGFloat = 2

    public init(count: Int, index: Int, onTap: @escaping (Int) -> Void = { _ in }) {
        self.count = count
        self.index = index
        self.onTap = onTap
    }
    // View to show dash bar ontop of images
    public var body: some View {
        GeometryReader { geo in
            // Calculates size of each dash bar based on how many images are being used
            let totalSpacing = spacing * CGFloat(max(count - 1, 0))
            let available = max(0, geo.size.width - sideInset*2 - totalSpacing)
            let barWidth = count > 0 ? available / CGFloat(count) : 0
            // Creates dashes based on above calculations
            HStack(spacing: spacing) {
                ForEach(0..<max(count, 1), id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(i == index ? activeFill : inactiveFill) // fills active image
                        if showStroke {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(strokeColor, lineWidth: strokeWidth)
                        }
                    }
                    .frame(width: barWidth, height: height)
                    .contentShape(Rectangle()) // Makes entire area tappable
                    .onTapGesture { onTap(i) }
                }
            }
            .padding(.horizontal, sideInset)
        }
        .frame(height: height)
    }
}

// MARK: - Dash bar pill
/// Rounded pill containing a `DashesIndicator`, typically used above carousels.
public struct DashBarPill: View {
    public let count: Int
    public let index: Int
    public var onTap: (Int) -> Void

    public init(count: Int, index: Int, onTap: @escaping (Int) -> Void) {
        self.count = count
        self.index = index
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColor.circleOne)
            DashesIndicator(count: count, index: index, onTap: onTap)
                .padding(.horizontal, 1)
        }
        .frame(height: 16)
        .padding(.horizontal, 14)
    }
}

// MARK: - Photo carousel
/// Displays images from remote URLs or asset names in a carousel with tappable dash indicators.
public struct PhotoCarousel: View {
    public enum Source { case urls([URL]), assets([String]) }

    @State private var index: Int = 0
    public var source: Source
    public var onIndexChanged: ((Int) -> Void)? = nil

    public init(source: Source, onIndexChanged: ((Int) -> Void)? = nil) {
        self.source = source
        self.onIndexChanged = onIndexChanged
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Dash indicator pill
            DashBarPill(count: count, index: index) { i in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { index = i }
                onIndexChanged?(i)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // Carousel image
            Group {
                switch source {
                case .urls(let urls) where !urls.isEmpty:
                    AsyncImage(url: urls[safe: index]) { phase in
                        switch phase {
                        case .empty: Color.gray.opacity(0.1)
                        case .success(let image): image.resizable()
                        case .failure: placeholder
                        @unknown default: placeholder
                        }
                    }
                case .assets(let names) where !names.isEmpty:
                    Image(names[safe: index] ?? "").resizable()
                default:
                    placeholder
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    index = (index + 1) % max(1, count)
                }
                onIndexChanged?(index)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .padding(.horizontal, 8)
        }
    }
    
    // returns the count of images for indexing the gallery
    private var count: Int {
        switch source { case .urls(let u): return u.count; case .assets(let a): return a.count }
    }
    
    //Place holder image for loading
    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.1)
            Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary)
        }
    }
}

// MARK: - Specials strip
/// Displays a horizontal scrollable list of `DisplayItem` specials with a header.
public struct SpecialsStripGeneric: View {
    public let items: [DisplayItem]
    public var title: String = "Menu Specials"
    public var onShowFullMenu: () -> Void

    public init(items: [DisplayItem], title: String = "Menu Specials", onShowFullMenu: @escaping () -> Void) {
        self.items = items
        self.onShowFullMenu = onShowFullMenu
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 12) {
            if !items.isEmpty {
                HStack(spacing: 10) {
                    Spacer()
                    Text(title).font(.title2.weight(.heavy)).foregroundColor(AppColor.primary)
                    Button(action: onShowFullMenu) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColor.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { onShowFullMenu() }
                // Shows the speicals in a horizontal scrollable
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { it in
                            VStack(spacing: 6) {
                                if let u = it.imageURL {
                                    // Fetches image for specials
                                    AsyncImage(url: u) { ph in
                                        switch ph {
                                        case .empty: Color.gray.opacity(0.1)
                                        case .success(let img): img.resizable()
                                        case .failure: Image(systemName: "photo").resizable().padding()
                                        @unknown default: EmptyView()
                                        }
                                    }
                                    .frame(width: 116, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.12))
                                        .frame(width: 116, height: 74)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Text(it.name).font(.caption).lineLimit(1).foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Amenity chips
/// Displays a horizontally scrollable row of amenity chips with icons and background gradient.
public struct AmenityChips: View {
    public let amenities: [String]
    public var background: LinearGradient
    public var hairline: Color

    public init(amenities: [String], background: LinearGradient, hairline: Color) {
        self.amenities = amenities
        self.background = background
        self.hairline = hairline
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Shows the ammenties with the icon
                ForEach(amenities, id: \.self) { a in
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: a))
                        Text(title(for: a))
                    }
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(background))
                    .overlay(Capsule().stroke(hairline, lineWidth: 1))
                    .foregroundColor(AppColor.primary)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
    
    // Helper function to normalize the ammenties title
    private func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Function to map icons to ammenties
    private func icon(for a: String) -> String {
        switch norm(a) {
        case "wifi", "wlan", "internet":
            return "wifi"

        case "vegan", "plantbased":
            return "leaf"

        case "chargers", "charging", "poweroutlets", "outlets", "sockets", "plugs":
            return "bolt.circle"

        case "seating", "seats", "tables", "chairs":
            return "chair"

        case "glutenfree", "glutenfreeoptions", "glutenfriendly":
            return "leaf.circle"

        default:
            return "questionmark.circle"
        }
    }
    
    /// Helper function - Clean up title
    private func title(for a: String) -> String {
        switch norm(a) {
        case "wifi", "wlan", "internet":
            return "Wi-Fi"
        case "vegan", "plantbased":
            return "Vegan"
        case "chargers", "charging", "poweroutlets", "outlets", "sockets", "plugs":
            return "Chargers"
        case "seating", "seats", "tables", "chairs":
            return "Seating"
        case "glutenfree", "glutenfreeoptions", "glutenfriendly":
            return "Gluten-Free"
        default:
            return a.capitalized
        }
    }
}


// MARK: - Recents strip
/// Shows recent images in a horizontal scroll view.
public struct RecentsStripGeneric: View {
    public let imageURLs: [URL]
    public init(imageURLs: [URL]) { self.imageURLs = imageURLs }

    public var body: some View {
        // Show recent iamges
        if !imageURLs.isEmpty {
            VStack(spacing: 10) {
                Text("Recents")
                    .font(.title2.weight(.heavy))
                    .foregroundColor(AppColor.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                // Makes the recents scrollable
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Show in scroallable hstack
                        ForEach(imageURLs, id: \.self) { u in
                            AsyncImage(url: u) { ph in
                                switch ph {
                                case .empty: Color.gray.opacity(0.1)
                                case .success(let img): img.resizable()
                                case .failure: Image(systemName: "photo").resizable().padding()
                                @unknown default: EmptyView() // Empty view if recents dont exist or there are errors
                                }
                            }
                            .frame(width: 160, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

/// A small capsule view displaying a cafe rating with a star icon.
struct Rating: View {
    /// The rating value (optional).
    let rating: Double?
    
    /// Background color of the capsule.
    var bgColor: Color = Color.white.opacity(0.2)
    
    /// Foreground color of text and star.
    var fgColor: Color = .white
    
    // View that shows rating in a pill with a star
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(rating.map { String(format: "%.1f", $0) } ?? "—")
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        // Background color and Foreground color can be passed to the struct
        .background(bgColor)
        .foregroundColor(fgColor)
        .clipShape(Capsule())
    }
}

// MARK: - Save FAB (floating action button)
/// Heart-shaped floating button to save/un-save a cafe.
public struct SaveFAB: View {
    public let isSaved: Bool
    public let heartBounce: Bool
    public let dim: Color
    public let shadow: Color
    public var onTap: () -> Void
    
    
    public init(isSaved: Bool, heartBounce: Bool, dim: Color, shadow: Color, onTap: @escaping () -> Void) {
        self.isSaved = isSaved
        self.heartBounce = heartBounce
        self.dim = dim
        self.shadow = shadow
        self.onTap = onTap
    }
    // View to save cafe from out of the Swipe Deck. I.e looking at cafe from search.
    public var body: some View {
        Button(action: onTap) {
            // Heart Icon
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(18)
                .background(isSaved ? AppColor.primary : dim)
                .clipShape(Circle())
                .shadow(color: shadow, radius: 10, y: 6)
                .scaleEffect(heartBounce ? 1.18 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: heartBounce)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save cafe") // Toggles save or unsave and triggers backend request.
    }
}

// MARK: - Address block
/// Displays cafe address and an optional pin button for user favorites.
public struct AddressBlock: View {
    public let address: String
    public let isPinned: Bool
    public var onPinTap: (() -> Void)? = nil

    public init(address: String, isPinned: Bool, onPinTap: (() -> Void)? = nil) {
        self.address = address
        self.isPinned = isPinned
        self.onPinTap = onPinTap
    }
    // Gives address with a pin logo. If the cafe has been pinned by the user it is red.
    public var body: some View {
        VStack(spacing: 12) {
            Divider()
            Button { onPinTap?() } label: {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(isPinned ? .red : AppColor.primary)
            }
            .buttonStyle(.plain)

            Text(address)
                .multilineTextAlignment(.center)
                .font(.body.weight(.semibold))
                .foregroundColor(AppColor.primary)
        }
    }
}

// MARK: - Collection extension
/// Safe index access to avoid out-of-bounds crashes.
public extension Collection {
    subscript(safe idx: Index) -> Element? { indices.contains(idx) ? self[idx] : nil }
}
