import SwiftUI

/// Root container for the app’s tabbed experience.
/// Manages tab selection and coordinates main screens like Home, Saved Cafes, Profile, Search, and Map.
struct ORAMainView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    /// Currently selected tab (default is home)
    @State private var tab: ORATab = .home

    /// Tracks undo actions for SwipeDeck
    @State private var undoTick: Int = 0

    /// Stores user's saved cafes
    @StateObject private var saved = SavedStore()

    /// Shared location manager for map and location-based features
    @StateObject private var locationManager = SharedLocationManager.shared

    /// Controls display of the Settings sheet
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    NavigationStack {
                        ZStack {
                            ORABackdrop()
                            VStack(spacing: 1) {
                                // Main header called
                                ORAHeader(
                                    onUndo: { undoTick += 1 },
                                    onSettings: { showSettings = true }
                                )
                                // Main swipe deck
                                SwipeDeck(
                                    undoTick: $undoTick,
                                    onSwipedCafe: { cafe, liked in
                                        if liked { saved.add(cafe) }
                                    }
                                )
                                .onAppear {
                                    // Permissions handler to calculcate the distance from current position to cafe on swipe card
                                    locationManager.requestPermissionIfNeeded()
                                    locationManager.requestLocation()
                                }

                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .toolbarBackground(.clear, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                
                // Selected tab is the saved page
                case .save:
                    NavigationStack {
                        ZStack {
                            ORABackdrop()
                            // Use SavedCafes view
                            SavedCafesView()
                                .environmentObject(saved)
                        }
                    }
                    .toolbarBackground(.clear, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                
                // Selected tab is the profile page
                case .profile:
                    ProfileView()
                    
                // Selected tab is the search page
                case .search:
                    NavigationStack {
                        ZStack {
                            ORABackdrop()
                            VStack(spacing: 12) {
                                ORAHeader(onSettings: { showSettings = true }) // Show settings when in search page
                                SearchView() // Use the seatch view
                            }
                        }
                    }
                    .toolbarBackground(.clear, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    
                // Selected tab is the map page
                case .map:
                    ZStack {
                        ORABackdrop()
                        VStack(spacing: 0) {

                            MapView() // Use map view
                        }
                        .toolbar(.hidden, for: .navigationBar)
                    }
                }
            }

            // Custom bottom tab bar
            ORABottomBar(selection: $tab)
                .padding(.bottom, 3)
        }
        .tint(AppColor.primary)
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(themeManager: theme)
            }
        }
    }
}

#Preview {
    ORAMainView()
        .environmentObject(SavedStore())
        .environmentObject(AuthManager())
        .environmentObject(ThemeManager())
}
