import SwiftUI
import UIKit

/// A grid displaying a collection of memory posts with support for preview and deletion.
/// - Parameters:
///   - memories: Array of `Memory` objects to display.
///   - cellSize: The minimum size for each grid cell.
///   - spacing: Spacing between grid items.
///   - outerPadding: Horizontal padding around the grid.
///   - onDelete: Closure called when a memory is deleted.
struct MemoriesGrid: View {
    let memories: [Memory]
    let cellSize: CGFloat
    let spacing: CGFloat
    let outerPadding: CGFloat
    var onDelete: (Memory) -> Void

    @Namespace private var zoomNS

    @State private var selected: Memory? = nil
    @State private var showPreview = false
    @State private var pendingDelete: Memory? = nil
    @State private var showDeleteConfirm = false

    /// Adaptive columns for LazyVGrid
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellSize), spacing: spacing, alignment: .center)]
    }

    var body: some View {
        ZStack {
            grid
            previewOverlay
        }
        // Confirmation dialog for deletion
        .confirmationDialog(
            "Delete this memory?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let m = pendingDelete {
                    if selected?.id == m.id { closePreview(animated: true) }
                    onDelete(m)
                }
                pendingDelete = nil
            }
            // Prompt user to confirm their delete
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This will remove the post and its image.")
        }
    }

    // MARK: - Grid of memory tiles
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(memories, id: \.id) { mem in
                MemoryTile(
                    mem: mem,
                    zoomNS: zoomNS,
                    isHidden: selected?.id == mem.id && showPreview,
                    onTap: { openPreview(with: mem) }, // Open preview (enlarged version of the memory)
                    onLongPress: { openPreview(with: mem) },
                    onDelete: { // Prompt delete
                        pendingDelete = mem
                        showDeleteConfirm = true
                    }
                )
            }
        }
        .padding(.horizontal, outerPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Memory preview overlay
    @ViewBuilder
    private var previewOverlay: some View {
        if let p = selected {
            MemoryPreviewOverlay(
                mem: p,
                zoomNS: zoomNS, // Changes size of the pic to zoom in
                onClose: { closePreview(animated: true) },
                onDeleteRequest: {
                    pendingDelete = p
                    showDeleteConfirm = true
                }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Open preview animation
    private func openPreview(with mem: Memory) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            selected = mem
            showPreview = true
        }
    }

    // MARK: - Close preview
    private func closePreview(animated: Bool) {
        let action = {
            showPreview = false
            selected = nil
        }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { action() }
        } else {
            action()
        }
    }
}

// MARK: - Single memory tile in grid
private struct MemoryTile: View {
    let mem: Memory
    var zoomNS: Namespace.ID
    let isHidden: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void
    
    private let corner: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            tileImage
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            
            // Date badge
            DateBadge(date: mem.createdAt)
                .padding(6)
        }
        .opacity(isHidden ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.8, maximumDistance: 25, perform: onLongPress)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mem.caption.isEmpty ? "Memory photo" : mem.caption)
    }
    
    @ViewBuilder
    // Actual tile image of the meory
    private var tileImage: some View {
        if let url = URL(string: mem.imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder // Use placeholders as fallbacks
                case .success(let image):
                    image
                        .resizable()
                        .matchedGeometryEffect(id: mem.id, in: zoomNS)
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .aspectRatio(1, contentMode: .fill)
        } else {
            placeholder
        }
    }
    // Placeholder view - gray background to prevent screen jittering
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            ProgressView()
                .controlSize(.regular)
                .tint(.secondary)
                .accessibilityHidden(true)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Overlay for memory preview
private struct MemoryPreviewOverlay: View {
    let mem: Memory
    var zoomNS: Namespace.ID
    let onClose: () -> Void
    let onDeleteRequest: () -> Void

    private let corner: CGFloat = 18
    // Show an enlarged version of the memory
    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            VStack {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: mem.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            cardShape
                                .fill(.regularMaterial)
                                .frame(minHeight: 240)
                                .overlay(ProgressView())
                                .matchedGeometryEffect(id: mem.id, in: zoomNS)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .background(cardShape.fill(.regularMaterial))
                                .clipShape(cardShape)
                                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                                .overlay(alignment: .topLeading) {
                                    //Show the data created
                                    DateBadge(date: mem.createdAt).padding(10)
                                }
                                // Display the cafe name and the caption for the memory
                                .overlay(alignment: .bottom) {
                                    if !mem.cafeTag.isEmpty || !mem.caption.isEmpty {
                                        MetaOverlay(cafeTag: mem.cafeTag, caption: mem.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.bottom, 8)
                                    }
                                }

                        case .failure:
                            cardShape
                                .fill(.regularMaterial)
                                .frame(minHeight: 240)
                                .overlay(Image(systemName: "photo").font(.title).foregroundStyle(.secondary))
                                .matchedGeometryEffect(id: mem.id, in: zoomNS)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    // Delete gesture
                    .onLongPressGesture(minimumDuration: 0.8) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        onDeleteRequest()
                    }

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(10)
                    .tint(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in if value.translation.height > 40 { onClose() } }
        )
        .transition(.opacity)
        .zIndex(1)
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Meta overlay showing cafe tag and caption
private struct MetaOverlay: View {
    let cafeTag: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !cafeTag.isEmpty { TagPill(text: cafeTag) }
            if !caption.isEmpty {
                Text(caption)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Small pill for cafe tag
private struct TagPill: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .foregroundStyle(.white)
        .accessibilityLabel("Cafe: \(text)")
    }
}

// MARK: - Badge for memory creation date
private struct DateBadge: View {
    let date: Date
    var body: some View {
        Text(RelativeDateTimeFormatter.shortString(from: date))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            .foregroundStyle(.white)
            .accessibilityLabel(RelativeDateTimeFormatter.fullString(from: date))
    }
}

// MARK: - Relative date formatting helpers
extension RelativeDateTimeFormatter {
    static func shortString(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
    static func fullString(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}
