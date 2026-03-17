import CoreLocation
import WidgetKit

// MARK: - Widget Location Manager
/// Manages the device's location specifically for widgets.
/// ObservableObject so widgets can reactively update when the location changes.
class WidgetLocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    // Shared singleton instance
    static let shared = WidgetLocationManager()
    
    // CoreLocation manager used to request and track location
    private let manager = CLLocationManager()
    
    // Published property containing the current device location
    @Published var currentLocation: CLLocation?
    
    // MARK: - Initializer
    /// Private initializer for singleton pattern.
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization() // Ensure app already requested permission
    }
    
    // MARK: - Location Requests
    /// Requests the current location once.
    func requestLocation() {
        manager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    /// Called when location updates are received.
    /// Updates `currentLocation` and triggers a widget refresh.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        WidgetCenter.shared.reloadAllTimelines() // Refresh all widgets when location changes
    }
    
    /// Called when location updates fail.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Widget location failed: \(error.localizedDescription)")
    }
}
