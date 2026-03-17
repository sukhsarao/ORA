import SwiftUI

/// Displays the menu for a given cafe, including drinks and food items.
/// Handles loading state, errors, and optional cafe title.
/// Uses `MenuCard` for each item and supports swipe/undo/back action.
struct MenuView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager
    var onUndo: (() -> Void)? = nil

    let cafeId: String               // ID of the cafe whose menu we want
    let cafeTitle: String?           // optional title to show at top

    @State private var menuItems: [MenuItem] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showSettings = false
    @StateObject private var cafeVM = CafeViewModel()

    var body: some View {
        ZStack {
            ORABackdrop()

            VStack(spacing: 0) {
                ORAHeader(onSettings: {showSettings = true})

                // Go back to the main page
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onUndo?()
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.uturn.backward") // Custom UI for back arrow
                            .font(.system(size: 15, weight: .semibold))
                            .padding(10)
                            .foregroundColor(AppColor.primary)
                            .background(Capsule().fill(AppColor.primary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    
                    Spacer()
                    // Show the cafes title on top
                    if let title = cafeTitle {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(AppColor.primary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                // Content - If loading then display loading sign else show the menu items.
                if isLoading {
                    ProgressView("Loading menu…")
                        .tint(AppColor.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMsg {
                    // Error handling for no menu
                    VStack(spacing: 12) {
                        Text("Failed to load menu")
                            .font(.headline)
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        // Catch error message and present retry option
                        Button("Retry") { loadMenus() }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppColor.primary)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if menuItems.isEmpty {
                    // Cafe does not have menu.
                    Text("No menu items available.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(menuItems) { MenuCard(item: $0) }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadMenus() }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(themeManager: theme)
            }
        }
    }

    // MARK: - Load menu items via CafeViewModel
    
    /// Fetches the menu items for the cafe using the view model.
    /// Updates `menuItems`, `isLoading`, and `errorMsg` based on result.
    private func loadMenus() {
        isLoading = true
        errorMsg = nil

        cafeVM.fetchMenus(for: cafeId) { items in
            DispatchQueue.main.async {
                self.menuItems = items
                self.isLoading = false
                if items.isEmpty {
                    self.errorMsg = "No menu items found for this cafe."
                }
            }
        }
    }
}


