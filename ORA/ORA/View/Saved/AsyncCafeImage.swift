import SwiftUI

/// A reusable image component that asynchronously loads and displays an image from a URL.
///
/// Used for showing images (e.g., cafe thumbnails or saved items) before they're fully loaded from the database.
/// Handles all loading states gracefully — empty, success, failure, or unknown.
///
/// Example:
/// ```swift
/// AsyncCardImage(url: imageURL, corner: 10, width: 120, height: 100)
/// ```
struct AsyncCardImage: View {
    /// Remote image URL (optional)
    let url: URL?

    /// Corner radius for rounded edges (default: 12)
    var corner: CGFloat = 12

    /// Optional fixed dimensions for the image frame
    var width: CGFloat? = nil
    var height: CGFloat? = nil

    /// How the image scales inside its frame (default: `.fit`)
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let u = url {
                // Async image loading with transition animation
                AsyncImage(url: u, transaction: .init(animation: .easeInOut)) { phase in
                    switch phase {
                    case .empty:
                        // Placeholder shown while image loads
                        ZStack {
                            Color.secondary.opacity(0.06)
                            ProgressView()
                                .controlSize(.regular)
                        }

                    case .success(let img):
                        // Successfully loaded image
                        img.resizable()
                            .aspectRatio(contentMode: contentMode)

                    case .failure:
                        // Shown when image fails to load
                        ZStack {
                            Color.secondary.opacity(0.08)
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                        }

                    @unknown default:
                        // Fallback for unexpected states
                        ZStack {
                            Color.secondary.opacity(0.06)
                            ProgressView()
                        }
                    }
                }

            } else {
                // No URL provided → show placeholder
                ZStack {
                    Color.secondary.opacity(0.08)
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Apply frame and rounded corners to the entire image container
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
