import SwiftUI
import CoreLocation

// MARK: - Swipeable Cafe Card
/// A swipeable card view for displaying cafe details, images, amenities, specials, and address.
/// Supports swipe gestures (like/dislike), and tap to cycle photos or navigate to menu.
struct SwipeCard: View {
    
    /// The cafe to display
    let cafe: Cafe
    
    /// Auth manager for pinned cafes
    @EnvironmentObject var authManager: AuthManager
    
    /// Current system color scheme (dark/light)
    @Environment(\.colorScheme) private var scheme
    
    /// Shared location manager to calculate distances
    @StateObject private var locationManager = SharedLocationManager.shared

    /// Closure called during swipe progress (0...1)
    var onProgress: (CGFloat) -> Void = { _ in }
    
    /// Closure called when swipe finishes; true if liked (swiped right)
    var onSwiped: (_ liked: Bool) -> Void

    // MARK: Gesture state
    @State private var translation: CGSize = .zero
    @State private var directionLock: Axis? = nil
    @State private var crossedThreshold = false
    @State private var photoIndex = 0
    @State private var goToMenu = false
    
    /// Horizontal swipe threshold in points
    private let swipeThreshold: CGFloat = 120

    /// Current swipe progress (0 to 1)
    private var progress: CGFloat { min(1, max(0, abs(translation.width) / swipeThreshold)) }
    
    /// Swipe direction
    private var isRight: Bool { translation.width > 0 }
    
    /// Tint color for swipe overlay
    private var swipeTint: Color { isRight ? .green : .red }
    
    /// Opacity of swipe overlay
    private var tintOpacity: Double { Double(min(0.12, 0.22 * progress)) }

    /// Card background gradient depending on color scheme
    private var cardBackground: LinearGradient {
        if scheme == .dark {
            return LinearGradient(colors: [AppColor.circleOne, AppColor.circleTwo],
                                  startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [AppColor.circleOne, AppColor.circleOne],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    photoGallery()             // Photo carousel
                    titleAndRating()           // Cafe name, rating, distance
                    Divider()
                    amenityRow()               // Horizontal row of key amenities
                    
                    // Specials
                    SpecialsStripGeneric(
                        items: (cafe.specials ?? []).map {
                            DisplayItem(id: $0.id ?? UUID().uuidString,
                                        name: $0.name,
                                        imageURL: $0.imageUrl.flatMap(URL.init(string:)))
                        },
                        onShowFullMenu: { goToMenu = true }
                    )
                    
                    // Amenity chips
                    if let amenities = cafe.amenities, !amenities.isEmpty {
                        AmenityChips(
                            amenities: amenities,
                            background: scheme == .dark
                                ? LinearGradient(colors: [AppColor.circleOne, AppColor.circleTwo], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [AppColor.circleOne.opacity(0.26), AppColor.circleTwo.opacity(0.18)], startPoint: .top, endPoint: .bottom),
                            hairline: scheme == .dark ? .white.opacity(0.06) : .black.opacity(0.06)
                        )
                    }

                    // Recents strip
                    if let recents = cafe.recents {
                        RecentsStripGeneric(imageURLs: recents.compactMap(URL.init(string:)))
                    }

                    // Address block with pin
                    AddressBlock(
                        address: cafe.address ?? "Unknown address",
                        isPinned: authManager.currentUser?.pinnedCafes.contains(cafe.id ?? "") ?? false,
                        onPinTap: {
                            if let cafeId = cafe.id {
                                authManager.togglePinnedCafe(cafeId: cafeId)
                            }
                        }
                    )
                    Spacer(minLength: 16)
                }
                .padding(16)
            }

            swipeBadge() // Like/Nope overlay badge
        }
        .frame(maxWidth: .infinity)
        .frame(height: 720)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(swipeTint)
                .opacity(tintOpacity)
                .blendMode(.softLight)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.08 + 0.06 * Double(progress)), radius: 16, x: 0, y: 10)
        .shadow(color: swipeTint.opacity(0.25 * progress), radius: 24, x: 0, y: 12)
        .offset(x: directionLock == .horizontal ? translation.width : 0,
                y: directionLock == .horizontal ? translation.height * 0.06 : 0)
        .rotationEffect(.degrees(directionLock == .horizontal ? Double(translation.width / 18) : 0))
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: translation)
        .gesture(dragGesture()) // Swipe gesture
        .background(
            // Navigation link to menu
            NavigationLink(
                destination: MenuView(
                    cafeId: cafe.id ?? "",
                    cafeTitle: cafe.name ?? "Unknown Cafe"
                ),
                isActive: $goToMenu
            ) { EmptyView() }
            .hidden()
        )
    }

    // MARK: - Photo gallery
    @ViewBuilder
    private func photoGallery() -> some View {
        if let urls = cafe.imageURLs, !urls.isEmpty {
            PhotoCarousel(source: .urls(urls)) { photoIndex = $0 }
        } else if let recents = cafe.recents {
            PhotoCarousel(source: .urls(recents.compactMap(URL.init(string:)))) { photoIndex = $0 }
        } else {
            PhotoCarousel(source: .assets([])) // Placeholder
        }
    }

    // MARK: - Title + rating + distance
    @ViewBuilder
    private func titleAndRating() -> some View {
        VStack {
            Text(cafe.name)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(AppColor.primary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Rating(rating: cafe.rating, bgColor: AppColor.circleTwo.opacity(0.22), fgColor: AppColor.primary)
                Text("|")

                if let lat = cafe.latitude, let lon = cafe.longitude,
                   let userLoc = locationManager.currentLocation {
                    Text(distanceString(from: userLoc,
                                        to: CLLocation(latitude: lat, longitude: lon)))
                } else {
                    Text("–")
                }
            }
            .foregroundColor(.secondary)
            .font(.system(.body, design: .rounded))
        }
    }

    // MARK: - Amenities row
    @ViewBuilder
    private func amenityRow() -> some View {
        HStack(spacing: 28) {
            if let amenities = cafe.amenities {
                if amenities.contains("wifi") { feature(icon: "wifi", label: "Wi-Fi") }
                if amenities.contains("vegan") { feature(icon: "leaf", label: "Vegan") }
                if amenities.contains("chargers") { feature(icon: "bolt.circle", label: "Chargers") }
            }
        }
    }

    // MARK: - Swipe badge (LIKE / NOPE)
    @ViewBuilder
    private func swipeBadge() -> some View {
        VStack {
            HStack {
                if isRight {
                    BadgeView(text: "LIKE", color: .green)
                        .opacity(Double(progress))
                        .rotationEffect(.degrees(-12))
                    Spacer()
                } else {
                    Spacer()
                    BadgeView(text: "NOPE", color: .red)
                        .opacity(Double(progress))
                        .rotationEffect(.degrees(12))
                }
            }
            Spacer()
        }
        .padding(20)
        .allowsHitTesting(false) // Badge doesn't block gestures
    }

    // MARK: - Drag gesture
    /// Handles swipe gestures and triggers swipe callbacks.
    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if directionLock == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if max(dx, dy) > 8 {
                        directionLock = dx > dy ? .horizontal : .vertical
                    }
                }
                if directionLock == .horizontal {
                    translation = value.translation
                    onProgress(progress)
                    let crossed = abs(translation.width) > swipeThreshold
                    if crossed && !crossedThreshold {
                        crossedThreshold = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if !crossed {
                        crossedThreshold = false
                    }
                }
            }
            .onEnded { value in
                defer {
                    translation = .zero
                    directionLock = nil
                    onProgress(0)
                }
                guard directionLock == .horizontal else { return }

                let dx = value.translation.width
                let predictedDx = (value.predictedEndLocation.x - value.location.x)
                let effective = dx + 0.25 * predictedDx

                if abs(effective) > swipeThreshold {
                    let liked = effective > 0
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        translation.width = UIScreen.main.bounds.width * (liked ? 1 : -1)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onSwiped(liked)
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        translation = .zero
                    }
                }
            }
    }

    // MARK: - Small reusable amenity chip
    @ViewBuilder
    private func feature(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColor.primary)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Badge used during swipe
/// Like/Nope indicator shown while dragging.
private struct BadgeView: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 3)
            )
            .foregroundColor(color)
    }
}
