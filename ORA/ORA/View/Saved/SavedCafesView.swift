import SwiftUI

/// Main view displaying all saved cafes and folders.
/// Supports folder creation, drag-to-delete, and drag-to-move between folders.
struct SavedCafesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var savedStore: SavedStore
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    @State private var showDeleteAllAlert = false
    @State private var haptic = false
    @State private var dragging: Cafe? = nil
    @State private var isOverDelete: Bool = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var showSettings = false
    @State private var selectedCafe: Cafe?
    @State private var selectedFolder: SavedFolder?
    @State private var swipeThreshold: CGFloat = 90

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        rootContent
            .task {
                savedStore.attachModelContext(modelContext)
                savedStore.bindToUser() // user based saved stores
                await savedStore.forceReloadFromRemote()
            }
            .sheet(isPresented: $showNewFolder) { newFolderSheet }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView(themeManager: theme) } }
            .navigationDestination(item: $selectedCafe) { cafe in
                CafePageView(cafeId: cafe.id ?? "", cafeTitle: cafe.name)
            }
            // Navigate to selected folder
            .navigationDestination(item: $selectedFolder) { folder in
                SavedFolderView(folderID: folder.id).environmentObject(savedStore)
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: haptic)
    }

    // MARK: - Root layout

    @ViewBuilder
    private var rootContent: some View {
        ZStack(alignment: .bottom) {
            ORABackdrop()
            // Create a new folder
            VStack(spacing: 0) {
                ORAHeader(
                    onAddFolder: { showNewFolder = true; haptic.toggle() }, //open new folder view
                    onSettings: { showSettings = true } // open settings view
                )
                folders
                // No saved cafes
                if isCompletelyEmpty {
                    emptyState.padding(.top, 80)
                    Spacer()
                } else {
                    gridSection // Main saved cafes
                }
            }

            trashButton // Trash button - if clicked triggers clear all prompt
        }
    }

    // MARK: - Folder section
    @ViewBuilder
    private var folders: some View {
        // Shows all the saved folders
        if !savedStore.folders.isEmpty || !savedStore.liked.isEmpty {
            FolderStrip(
                likedCount: savedStore.liked.count,
                folders: savedStore.folders,
                onAllTapped: { },
                onFolderTapped: { f in selectedFolder = f }, // Show cafes in selected folder
                onCreateTapped: { showNewFolder = true }, // Create new folder
                // Drop cafe to folder
                onDropToFolder: { folder, ids in
                    guard let id = ids.first else { return false }
                    return moveCafe(withID: id, to: folder)
                }
            )
            .padding(.top, 2)
        }
    }

    // MARK: - Grid of saved cafes
    private var gridSection: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                // Show all the saved cafes
                ForEach(savedStore.liked) { cafe in
                    CafeTileButton(
                        cafe: cafe,
                        isDragging: dragging?.id == cafe.id,
                        onTap: {
                            selectedCafe = cafe
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            haptic.toggle()
                        },
                        onLongPress: {
                            // Trigger dragging
                            dragging = cafe
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            haptic.toggle()
                        },
                        onDragEnd: { translation in
                            guard dragging?.id == cafe.id else { return }
                            if translation.width <= -swipeThreshold {
                                savedStore.removeCompletely(cafe) // Delete cafe if dragged to tash
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                haptic.toggle()
                            }
                            dragging = nil
                        }
                    )
                    .onDrop(
                        of: [.text],
                        delegate: CafeDropDelegate(
                            item: cafe,
                            list: $savedStore.liked,
                            dragging: $dragging
                        )
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .padding(.bottom, 50)
        }
        .refreshable { await refresh() }
    }
    
    private var isCompletelyEmpty: Bool {
        savedStore.liked.isEmpty && savedStore.folders.allSatisfy { $0.cafes.isEmpty }
    }
    
    // State for when there are no saved cafes
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColor.primary)
            Text("No saved cafes yet").font(.headline)
            Text("Swipe right on a cafe and it’ll appear here.")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Trash Button
    private var trashButton: some View {
        Button {
            // If not dragging and trash is clicked then trigger the delete all saved cafes prompt
            if dragging == nil { showDeleteAllAlert = true }
        } label: {
            // General trash can UI
            Image(systemName: "trash.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(isOverDelete ? .red : .primary)
                .padding(18)
                .background(Circle().fill(Color(.secondarySystemBackground)))
                .scaleEffect(isOverDelete ? 1.12 : 1.0)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isOverDelete)
        }
        .dropDestination(for: String.self,
                         action: { items, _ in
            guard let id = items.first,
                  let cafe = cafeBy(id: id) else { return false }
            savedStore.removeCompletely(cafe) // if the cafe hits the trash can then delete the cafe from the saved
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            haptic.toggle()
            return true
        },
                         isTargeted: { hovering in
            isOverDelete = hovering
        })
        .padding(.bottom, 65)
        .alert("Clear all saved cafes?", isPresented: $showDeleteAllAlert) {
            Button("Delete All", role: .destructive) { savedStore.removeAll() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - New Folder Sheet
    private var newFolderSheet: some View {
        NavigationView {
            Form {
                // Prompts for creating a new folder
                Section(header: Text("Folder Name")) {
                    TextField("e.g. Date Spots", text: $newFolderName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showNewFolder = false }
                }
                // Creating a new folder
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        // Save the new folder to SD
                        savedStore.addFolder(name: name)
                        newFolderName = ""
                        showNewFolder = false
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers
    private func moveCafe(withID id: String, to folder: SavedFolder) -> Bool {
        // check if cafe is in the main liked page
        if let cafe = savedStore.liked.first(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                savedStore.moveCafe(cafe, to: folder) // Drag and drop cafe to folder
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        }
        // Otherwise flattenthe folders and move the cafe to a new folder
        if let cafe = savedStore.folders.flatMap(\.cafes).first(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                savedStore.moveCafe(cafe, to: folder)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        }
        return false
    }
    // Gets a cafe by the id within the saved cafes
    private func cafeBy(id: String) -> Cafe? {
        let all: [Cafe] = savedStore.liked + savedStore.folders.flatMap(\.cafes)
        return all.first { $0.id == id }
    }
    
    // Refresh to update the new saved states
    private func refresh() async {
        await savedStore.forceReloadFromRemote()
    }
}

// MARK: - CafeTileButton
/// Small tappable tile representing a saved cafe with drag and swipe gestures.
private struct CafeTileButton: View {
    let cafe: Cafe
    let isDragging: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onDragEnd: (_ translation: CGSize) -> Void

    var body: some View {
        Button(action: onTap) {
            CafeImageCard(cafe: cafe, corner: 12, showTitle: true, highlight: isDragging)
                .frame(height: 150)
        }
        .buttonStyle(.plain)
        .gesture(LongPressGesture(minimumDuration: 1.0).onEnded { _ in onLongPress() })
        .simultaneousGesture(DragGesture(minimumDistance: 8).onEnded { value in onDragEnd(value.translation) })
        .draggable(cafe.id ?? "")
    }
}

// MARK: - FolderStrip
/// Horizontal scroll view showing folders with optional drop targets.
struct FolderStrip: View {
    let likedCount: Int
    let folders: [SavedFolder]
    var onAllTapped: () -> Void
    var onFolderTapped: (SavedFolder) -> Void
    var onCreateTapped: () -> Void
    var onDropToFolder: (SavedFolder, [String]) -> Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Show all folders in a horizontal strip
                ForEach(folders) { f in
                    FolderChip(
                        folder: f,
                        previewURL: firstPreviewURL(for: f),
                        onTap: { onFolderTapped(f) }, // Go to folder if tapped
                        onDropIDs: { ids in onDropToFolder(f, ids) } // Add cafe into folder if dropped
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    // Cached image from first cafe in the folder
    private func firstPreviewURL(for folder: SavedFolder) -> URL? {
        if let u = folder.cafes.first?.imageURLs?.first { return u }
        if let s = folder.cafes.first?.imageUrl, let u = URL(string: s) { return u }
        return nil
    }
}
