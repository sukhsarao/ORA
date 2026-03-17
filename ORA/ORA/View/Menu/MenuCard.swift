import SwiftUI

/// A card view displaying a menu item (food or drink) with image, price(s), and description.
/// For drinks, supports expanded view to show all sizes and a compact size selector.
struct MenuCard: View {
    let item: MenuItem

    // UI state
    @State private var expanded: Bool = false // expands to show all sizes (for drinks)
    @State private var selectedSize: String = "medium" // highlighted size when collapsed

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Image (remote via AsyncImage)
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.08)
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 70)
                                .foregroundColor(.secondary)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        @unknown default:
                            EmptyView()
                                .frame(width: 70, height: 70)
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.secondary)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Item details
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(AppColor.primary)

                    // Food -> single price
                    if item.type.lowercased() == "food" {
                        if let priceRaw = item.price, !priceRaw.isEmpty {
                            Text(formatted(priceRaw))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Drink -> collapsed or expanded sizes
                    else if item.type.lowercased() == "drink" {
                        // When not expanded show selected (default medium)
                        if !expanded {
                            // If sizes exist show medium or the first size available
                            if let sizes = item.sizes, !sizes.isEmpty {
                                // pick medium if available otherwise first key
                                let medium = sizes.keys.first { $0.lowercased() == "medium" } ?? sizes.keys.first!
                                let displayedSize = selectedSizeAvailable(in: sizes) ?? medium
                                let priceRaw = sizes[displayedSize] ?? sizes[medium] ?? ""
                                Text("Price (\(displayedSize.capitalized)): \(formatted(priceRaw))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                // fallback: maybe price field contains a single value
                                if let priceRaw = item.price, !priceRaw.isEmpty {
                                    Text(formatted(priceRaw))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // expanded: list all sizes
                            if let sizes = item.sizes, !sizes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(sizes.keys.sorted(by: { $0 < $1 }), id: \.self) { key in
                                        HStack {
                                            Text(key.capitalized)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(formatted(sizes[key] ?? ""))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.top, 4)
                            } else if let priceRaw = item.price, !priceRaw.isEmpty {
                                Text(formatted(priceRaw))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No price information")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Description
                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(expanded ? nil : 3)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color("MenuCard").opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                // For drinks toggle expand; for food maybe do nothing
                if item.type.lowercased() == "drink" {
                    withAnimation(.spring()) {
                        expanded.toggle()
                    }
                }
            }

            // If drink and not expanded, show a small hint row of the sizes (optional)
            if item.type.lowercased() == "drink", let sizes = item.sizes, !sizes.isEmpty {
                // show a compact horizontally scrollable list of sizes (highlight selected)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let keys = sizes.keys.sorted()
                        ForEach(keys, id: \.self) { key in
                            let isSelected = key.lowercased() == selectedSize.lowercased()
                            Button(action: {
                                withAnimation { selectedSize = key }
                            }) {
                                Text("\(key.capitalized) \(formatted(sizes[key] ?? ""))")
                                    .font(.caption2)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(isSelected ? AppColor.primary : Color(.systemGray6))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 36)
            }
        }
    }

    // MARK: - Helpers

    /// Formats a raw price string into $X.XX if numeric
    private func formatted(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip possible $ if user stored it
        let noDollar = trimmed.replacingOccurrences(of: "$", with: "")
        if let d = Double(noDollar) {
            return String(format: "$%.2f", d)
        } else {
            return trimmed
        }
    }

    /// Returns a valid selected size if the default is not present
    private func selectedSizeAvailable(in sizes: [String: String]) -> String? {
        if sizes.keys.contains(where: { $0.lowercased() == selectedSize.lowercased() }) {
            return selectedSize
        }
        // Fallback to "medium" or first available key
        if let m = sizes.keys.first(where: { $0.lowercased() == "medium" }) { return m }
        return sizes.keys.first
    }
}
