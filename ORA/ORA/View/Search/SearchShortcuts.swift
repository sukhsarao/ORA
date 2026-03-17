import SwiftUI

/// Section showing a grid of popular search shortcuts.
struct SearchShortcutsSection: View {
    let terms = ["iced tea","iced coffee","cheese cake","matcha","shake","frappe","latte","hot chocolate","cappuccino","mocha","waffle","sandwich"]
    var onChoose: (String) -> Void

    var body: some View {
        SuggestionGridRemote(terms: terms, onPick: onChoose)
            .scrollDismissesKeyboard(.immediately)
            .padding(.horizontal, 8)
    }
}

/// Grid of suggestion chips with optional remote images.
struct SuggestionGridRemote: View {
    let terms: [String]
    var onPick: (String) -> Void
    @State private var urls: [String: URL?] = [:]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(terms, id: \.self) { term in
                    // Gives suggestions to seatch based on terms
                    SuggestionChip(title: term, imageURL: urls[term] ?? nil) {
                        onPick(term)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        // Pre-fetch images for all terms asynchronously
        .task(id: terms) {
            let map = await UnsplashClient.shared.prefetch(terms)
            await MainActor.run { self.urls = map }
        }
    }
}

/// Single tappable suggestion chip with optional image.
private struct SuggestionChip: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let imageURL: URL?
    var onTap: () -> Void
    
    // Simple card background function based on color scheme
    private var cardBackground: LinearGradient {
        if scheme == .dark {
            LinearGradient(colors: [AppColor.circleOne, AppColor.circleTwo],
                           startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: [AppColor.circleOne.opacity(0.26), AppColor.circleTwo.opacity(0.18)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var hairline: Color {
        scheme == .dark ? .white.opacity(0.06) : .black.opacity(0.06)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Async image with placeholder/fallback
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty: Color.gray.opacity(0.12)
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").resizable().scaledToFit().padding(6)
                    @unknown default: Color.gray.opacity(0.12)
                    }
                }
                .frame(width: 56, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                // Show the suggested search titles
                Text(title)
                    .font(.body)
                    .foregroundColor(AppColor.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(hairline, lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.10), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }
}
