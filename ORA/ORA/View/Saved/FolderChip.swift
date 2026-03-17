import SwiftUI

/// A tappable folder chip showing the folder name, item count, and optional preview image.
/// Supports drag-and-drop for moving cafes into the folder.
struct FolderChip: View {
    @Environment(\.colorScheme) private var scheme // Detect current light/dark mode

    let folder: SavedFolder          // Folder data (name and cafes)
    let previewURL: URL?             // Optional image URL to show as folder preview
    var onTap: () -> Void            // Action when folder chip is tapped
    var onDropIDs: (([String]) -> Bool)? // Optional closure for handling dropped cafe IDs

    @State private var isTargeted = false // Whether a drag item is hovering over the chip

    // MARK: - Styling constants
    private let chipRadius: CGFloat = 12
    private let padH: CGFloat = 16
    private let padV: CGFloat = 8
    private var subtleAnim: Animation { .spring(response: 0.32, dampingFraction: 0.95) } // Smooth hover animation
    private var shadowColor: Color { Color.black.opacity(scheme == .dark ? 0.20 : 0.08) } // Shadow color adapts to theme
    
    var body: some View {
        // The whole chip is tappable
        Button(action: onTap) {
            HStack(spacing: 10) {
                
                // MARK: Folder icon / preview
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColor.circleTwo.opacity(scheme == .dark ? 0.20 : 0.25)) // Background for icon
                    .frame(width: 28, height: 28)
                    .overlay(
                        Group {
                            if let u = previewURL {
                                // If preview image exists, show it
                                AsyncCardImage(
                                    url: u,
                                    corner: 8,
                                    width: 28,
                                    height: 28,
                                    contentMode: .fill
                                )
                            } else {
                                // Default folder system icon
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppColor.primary)
                            }
                        }
                    )

                // MARK: Folder name and item count
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                        .lineLimit(1) // Single-line name
                    
                    Text("\(folder.cafes.count) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1) // Single-line count
                }

                Spacer(minLength: 0)
                
                // Chevron to indicate tap/action
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, padH)
            .padding(.vertical, padV)
            .background(
                RoundedRectangle(cornerRadius: chipRadius, style: .continuous)
                    .fill(chipFill(scheme)) // Background fill based on theme
                    .overlay(
                        RoundedRectangle(cornerRadius: chipRadius, style: .continuous)
                            .stroke(
                                // Highlight border when drag item hovers
                                isTargeted ? AppColor.primary
                                           : Color.black.opacity(scheme == .dark ? 0.20 : 0.06),
                                lineWidth: isTargeted ? 2 : 1
                            )
                    )
            )
            .frame(height: 44)
            .shadow(color: shadowColor, radius: 8, y: 3)
            .animation(subtleAnim, value: isTargeted) // Animate border changes smoothly
        }
        .buttonStyle(.plain) // Disable default button styles
        
        // MARK: Drag-and-drop support
        .dropDestination(
            for: String.self,
            action: { items, _ in onDropIDs?(items) ?? false }, // Call closure when items dropped
            isTargeted: { hovering in isTargeted = hovering }   // Track hovering state
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.name), \(folder.cafes.count) cafes") // Accessibility text
    }
}
