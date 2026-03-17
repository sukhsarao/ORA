import SwiftUI

/// Shows a single saved folder with cafes.
/// Supports search, sorting, list/grid layout, drag & drop, and deleting cafes.
struct SavedFolderView: View {
    @EnvironmentObject var savedStore: SavedStore
    let folderID: String

    @Environment(\.colorScheme) private var scheme

    @State private var query: String = ""
    @State private var sort: SortMode = .nameAZ
    @State private var useListLayout: Bool = false
    @State private var isTargetedDrop: Bool = false
    @State private var selectedCafe: Cafe?

    @State private var draggingCafe: Cafe?
    @State private var isOverTrash: Bool = false
    @State private var showDeleteFolderAlert = false
    @State private var swipeThreshold: CGFloat = 90
    @State private var isRefreshing = false


    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        if let folder = savedStore.folders.first(where: { $0.id == folderID }) {
            content(for: folder)
        } else {
            Text("Folder not found")
                .foregroundStyle(.secondary)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Main content
    @ViewBuilder
    private func content(for folder: SavedFolder) -> some View {
        let cafes = filteredSorted(folder.cafes)

        ZStack(alignment: .bottom) {
            ORABackdrop()

            VStack(spacing: 10) {
                if !folder.cafes.isEmpty { controlsBar }
                if cafes.isEmpty {
                    emptyState.padding(.top, 8)
                } else if useListLayout {
                    listLayout(for: folder, cafes: cafes)
                } else {
                    gridLayout(for: folder, cafes: cafes)
                }
            }
            .padding(.vertical, 8)

            // Floating trash target (removes cafe from THIS folder only)
            if !cafes.isEmpty {
                Button {} label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isOverTrash ? .red : .primary)
                        .padding(18)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                        .scaleEffect(isOverTrash ? 1.12 : 1.0)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isOverTrash) // Checks if the cafe is hovered over the trash
                }
                .contentShape(Rectangle())
                .zIndex(50)
                .dropDestination(for: String.self,
                                 action: { items, _ in
                                     guard let id = items.first,
                                           let cafe = folder.cafes.first(where: { $0.id == id }) else { return false }
                                     savedStore.removeCafe(cafe, fromFolderID: folder.id)
                                     UINotificationFeedbackGenerator().notificationOccurred(.success)
                                     draggingCafe = nil
                                     return true
                                 },
                                 isTargeted: { hovering in
                                     isOverTrash = hovering
                                 })
                .padding(.bottom, 65)
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)

        // Top-right toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteFolderAlert = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete folder")
            }
        }
        // Delete folder confirmations
        .alert("Delete this folder?", isPresented: $showDeleteFolderAlert) {
            Button("Delete Folder", role: .destructive) { savedStore.deleteFolder(folder) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(folder.cafes.isEmpty
                 ? "This can’t be undone."
                 : "This will remove the folder. Cafes won’t be unsaved.")
        }
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)

        // Folder-level drop target (move/add into this folder)
        .dropDestination(for: String.self,
                         action: { items, _ in
                             guard let id = items.first else { return false }
                             if let cafe = (savedStore.liked + savedStore.folders.flatMap(\.cafes))
                                 .first(where: { $0.id == id }) {
                                 savedStore.moveCafe(cafe, to: folder)
                                 UINotificationFeedbackGenerator().notificationOccurred(.success)
                                 return true
                             }
                             return false
                         },
                         isTargeted: { hovering in
                             isTargetedDrop = hovering
                         })
        // Navigation to cafe page
        .navigationDestination(item: $selectedCafe) { cafe in
            CafePageView(cafeId: cafe.id ?? "", cafeTitle: cafe.name)
        }
    }
    
    // Search in saved cafes
    private var controlsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

                TextField("Search in folder", text: $query)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                // query for the search value and clear search
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(chipFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(line(scheme), lineWidth: 1)
            )
            .shadow(color: subtleShadow(scheme), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 16)
            // Sort cafes in the folders
            HStack(spacing: 12) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode)
                        }
                    }
                } label: {
                    // Sort folders alphabetically
                    Label(sort.label, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(chipFill(scheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(line(scheme), lineWidth: 1)
                        )
                        .shadow(color: subtleShadow(scheme), radius: 3, x: 0, y: 1)
                }

                Spacer()
                // Grid and List layouts
                Button {
                    useListLayout.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    // Images to toggle grid v list layouts
                    Image(systemName: useListLayout ? "rectangle.grid.2x2" : "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(chipFill(scheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(line(scheme), lineWidth: 1)
                        )
                        .shadow(color: subtleShadow(scheme), radius: 3, x: 0, y: 1)
                }
                .accessibilityLabel(useListLayout ? "Switch to grid" : "Switch to list")
            }
            .padding(.horizontal, 16)
        }
    }

    
    // Grid layout patten
    private func gridLayout(for folder: SavedFolder, cafes: [Cafe]) -> some View {
        ScrollView {
            // Show cafes in grid
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(cafes) { cafe in
                    // Make each cafe in the grid a button if clicked show its page. Also check if its being dragged
                    Button {
                        selectedCafe = cafe
                        UIImpactFeedbackGenerator(style: .light).impactOccurred() // haptic feedback for selected cafe
                    } label: {
                        CafeImageCard(
                            cafe: cafe,
                            corner: 12,
                            showTitle: true,
                            highlight: draggingCafe?.id == cafe.id
                        )
                        .frame(height: 150)
                    }
                    .buttonStyle(.plain)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.8)
                            .onEnded { _ in draggingCafe = cafe }
                    )
                    // If being dragged into the trash can then delete teh cafe from the folder
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .local)
                            .onEnded { value in
                                guard draggingCafe?.id == cafe.id else { return }
                                if value.translation.width <= -90 {
                                    savedStore.removeCafe(cafe, fromFolderID: folder.id) // remove from swift data
                                    UINotificationFeedbackGenerator().notificationOccurred(.success) // Provide feedback
                                }
                                draggingCafe = nil
                            }
                    )
                    .draggable(cafe.id ?? "")
                    .contextMenu {
                        moveMenu(for: cafe, currentFolderID: folder.id)
                        Button(role: .destructive) {
                            savedStore.removeCafe(cafe, fromFolderID: folder.id) // Remove cafe from folder
                        } label: {
                            Label("Remove from folder", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .padding(.bottom, 50)
        }.refreshable { await refresh() }
    }
    
    // List layout
    private func listLayout(for folder: SavedFolder, cafes: [Cafe]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(cafes) { cafe in
                    Button {
                        selectedCafe = cafe
                        UIImpactFeedbackGenerator(style: .light).impactOccurred() //haptic feedback for selected cafe
                    } label: {
                        CafeRow(cafe: cafe, dragging: draggingCafe?.id == cafe.id)
                    }
                    .buttonStyle(.plain)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.8) // Long hold to trigger dragging cafe
                            .onEnded { _ in draggingCafe = cafe }
                    )
                    .draggable(cafe.id ?? "")
                    .contextMenu {
                        moveMenu(for: cafe, currentFolderID: folder.id)
                        Button(role: .destructive) {
                            savedStore.removeCafe(cafe, fromFolderID: folder.id) // remove cafe from folder
                        } label: {
                            Label("Remove from folder", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 40)
        }.refreshable { await refresh() }

    }
    
    // State for when folder is empty
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 40)
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(AppColor.primary)
            Text("This folder is empty")
                .font(.headline)
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.horizontal, 24)
    }


    // MARK: - Helpers
    /// Helper function to sort cafes alphabetically or reverse alphabetically in a folder.
    private func filteredSorted(_ cafes: [Cafe]) -> [Cafe] {
        var out = cafes
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = query.lowercased()
            out = out.filter { c in
                c.name.lowercased().contains(q) ||
                (c.address?.lowercased().contains(q) ?? false)
            }
        }
        // Sort alphabetically
        switch sort {
        case .nameAZ:
            out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // Sort reverse alphabetcially
        case .nameZA:
            out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
        return out
    }
    
    /// Helper function to move a cafe from one folder to another during long press.
    private func moveMenu(for cafe: Cafe, currentFolderID: String) -> some View {
        Menu {
            let otherFolders = savedStore.folders.filter { $0.id != currentFolderID } // Get other folder id's except current folder
            if otherFolders.isEmpty {
                Text("No other folders").foregroundStyle(.secondary)
            } else {
                ForEach(otherFolders) { folder in
                    Button {
                        savedStore.moveCafe(cafe, to: folder) // Move cafe to new folder
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Move to \"\(folder.name)\"", systemImage: "folder")
                    }
                }
            }
        } label: {
            Label("Move...", systemImage: "arrowshape.turn.up.right")
        }
    }
    // Simple refresh function to reload saved state
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await savedStore.forceReloadFromRemote()
    }

}

// MARK: - Sort mode
private enum SortMode: CaseIterable {
    case nameAZ, nameZA
    var label: String {
        switch self {
        case .nameAZ: return "Name A–Z"
        case .nameZA: return "Name Z–A"
        }
    }
    var icon: String {
        switch self {
        case .nameAZ: return "textformat.abc"
        case .nameZA: return "textformat.abc.dottedunderline"
        }
    }
}
