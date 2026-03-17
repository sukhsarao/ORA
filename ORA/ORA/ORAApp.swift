import SwiftUI
import FirebaseCore
import GooglePlaces
import FirebaseAppCheck

// MARK: - AppCheck Provider Factory for App Attest
/// Provides an AppCheck provider using App Attest for production builds.
/// Ensures Firebase requests are validated via App Attest.
class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}

// MARK: - AppDelegate
/// Handles Firebase setup and AppCheck configuration.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        #if DEBUG
        // Use AppCheck debug provider in debug mode
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
        // Configure Firebase
        FirebaseApp.configure()
        return true
    }
}
// MARK: - ORAApp
/// Main SwiftUI entry point of the ORA app.
@main
struct ORAApp: App {
    
    // MARK: - StateObjects for global app state
    @StateObject private var authManager = AuthManager()     // Manages user authentication
    @StateObject private var theme       = ThemeManager()    // Manages theme mode (light/dark)
    @StateObject private var memories    = MemoryStore()     // Manages user memories
    
    // Google Places API key
    private let accessKey: String = Secrets.value(for: "GOOGLE_PLACES_API_KEY")
    
    // MARK: - Initializer
    init() {
        // Provide the Google Places API key to the SDK
        GMSPlacesClient.provideAPIKey(accessKey)
    }
    // Connect AppDelegate to SwiftUI lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                // Show splash screen while loading auth state
                if authManager.isLoading {
                    SplashScreenView()
                }
                // If user is signed in, show main app
                else if authManager.currentUser != nil {
                    ORAMainView()
                }
                // Otherwise, show welcome screen
                else {
                    WelcomeView()
                }
            }
            // Inject environment objects for use throughout the app
            .environmentObject(authManager)
            .environmentObject(theme)
            .environmentObject(memories)
            // Apply theme color scheme
            .preferredColorScheme(theme.theme.colorScheme)
            // Core Data / Model container setup for local data persistence
            .modelContainer(for: [FolderSD.self, CafeRefSD.self, SearchSnapshot.self])
        }
    }
}
