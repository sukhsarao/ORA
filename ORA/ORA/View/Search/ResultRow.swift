import SwiftUI

/// # ResultRow
///
/// A compact, tappable row that displays a **menu item** result within a cafe:
/// - Thumbnail image (item photo or cafe photo fallback
/// - Item name and optional **price**
///
/// The row is intended to be used inside a `List`/`ScrollView` and sized to 72pt height.
///
/// ## Accessibility
/// - Provides a combined `accessibilityLabel` summarizing the item, price, rating, and cafe.
/// - Decorative icons (photo placeholder, star , map pin) are hidden from VoiceOver.
///
struct ResultRow: View {
    /// Search result model
    let row: Row

    /// Fallback remote image source
    @State private var remoteURL: URL?

    /// Placeholder color when no image is loaded
    private var placeholderFill: Color { Color(UIColor.secondarySystemFill) }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: row.imageURL ?? remoteURL, transaction: .init(animation: .easeInOut)) { phase in
                switch phase {
                case .empty:
                    placeholderFill
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    ZStack {
                        placeholderFill
                        Image(systemName: "photo")
                            .font(.headline)
                            .foregroundStyle(.tertiary)
                    }
                @unknown default:
                    placeholderFill
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            // Textual content
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Item name
                    Text(row.itemName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Price (if any)
                    if let price = row.price {
                        Text(String(format: "$%.2f", price))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    // Rating chip (if any)
                    if let rating = row.cafeRating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                }

                // Cafe name
                Text(row.cafeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Address section
                if let addr = row.cafeAddress, !addr.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(addr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 72, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore) // Use custom label below
        .accessibilityLabel(accessibilitySummary)
        .task(id: row.imageURL == nil ? row.itemName : "") {
            guard row.imageURL == nil else { return }
            remoteURL = await UnsplashClient.shared.url(for: row.itemName)
        }
    }

    /// Builds a concise screen reader summary of the row.
    private var accessibilitySummary: String {
        var parts: [String] = [row.itemName]
        if let price = row.price {
            parts.append(String(format: "$%.2f", price))
        }
        if let rating = row.cafeRating {
            parts.append("rated \(String(format: "%.1f", rating))")
        }
        parts.append("at \(row.cafeName)")
        return parts.joined(separator: ", ")
    }
}
