import SwiftUI

/// # RecentSearchesSection
///
/// A compact, card-styled list of recently performed searches.
/// Each row shows the query text, a small count badge of results,
/// and a relative time label. Tapping a row triggers `onPick`.
///
/// The section also includes a trailing “Clear all” action.

/// ## UI
/// - Uses your design tokens: `cardFill(_:)`, `line(_:)`, `subtleShadow(_:)`, `chipFill(_:)`.
/// - Renders a rounded card with separators between rows.
/// - Each row is a full-width tappable button (`.buttonStyle(.plain)`).
///
/// ## Accessibility
/// - “Clock” icon is decorative; textual labels contain the key information.
/// - Dynamic type friendly
///
/// ## Parameters
/// - `items`: Recent queries to display.
/// - `onPick`: Called when a row is selected (e.g., to restore cached results).
/// - `onClearAll`: Clears all recents (caller handles persistence).
struct RecentSearchesSection: View {
    @Environment(\.colorScheme) private var scheme

    /// Recent queries to display.
    let items: [RecentItem]

    /// Called when a recent item is selected.
    var onPick: (RecentItem) -> Void

    /// Called when "Clear all" is tapped.
    var onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack {
                // Shows recent searches
                Text("Recent searches")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
                // Option to clear all recent searches
                Button("Clear all", action: onClearAll)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Clears all recent searches")
            }
            .padding(.horizontal)

            // Show recent searchs in a list format
            VStack(spacing: 0) {
                ForEach(items) { it in
                    Button { onPick(it) } label: {
                        HStack(spacing: 12) {
                            // Decorative clock
                            ZStack {
                                Circle()
                                    .fill(chipFill(scheme))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityHidden(true)

                            // Query + meta
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.query)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                // Count the number of results in the search
                                HStack(spacing: 6) {
                                    CountBadge(
                                        text: "\(it.rows.count) item\(it.rows.count == 1 ? "" : "s")"
                                    )
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)

                                    Text(relativeTime(it.when))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .accessibilityElement(children: .combine)
                            }

                            Spacer(minLength: 0)
                            // Indicate search is clickable
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(it.query), \(it.rows.count) results, \(relativeTime(it.when))")

                    // Row separator(omit for last)
                    if it.id != items.last?.id {
                        Rectangle()
                            .fill(line(scheme))
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.leading, 52)
                            .accessibilityHidden(true)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardFill(scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(line(scheme), lineWidth: 1)
                    )
                    .shadow(color: subtleShadow(scheme), radius: 10, y: 4)
            )
            .padding(.horizontal)
        }
    }

    /// Formats a `Date` into a short relative string...
    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
