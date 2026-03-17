import SwiftUI

/// A simple row displaying a cafe’s thumbnail and name, used in list or folder views.
struct CafeRow: View {
    let cafe: Cafe
    var dragging: Bool = false

    @Environment(\.colorScheme) private var scheme
    private let pad: CGFloat = 12

    var body: some View {
        HStack(spacing: 12) {
            // Cafe image thumbnail
            CafeImageCard(cafe: cafe, corner: 10, showTitle: false)
                .frame(width: 56, height: 56)

            // Cafe name
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.headline)
                    .foregroundStyle(AppColor.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Navigation arrow
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(pad)
    }
}

/// A small circular divider used to separate inline details.
public struct DividerDot: View {
    public init() {}

    public var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 4, height: 4)
    }
}
