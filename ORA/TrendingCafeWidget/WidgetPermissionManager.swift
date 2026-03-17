import Foundation
import CoreLocation

// MARK: - Widget Permission Manager
/// Singleton class responsible for requesting and tracking location permission status.
/// ObservableObject so SwiftUI views (including widgets) can reactively update when permission changes.
class WidgetPermissionManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    // Shared singleton instance
    static let shared = WidgetPermissionManager()
    
    // CoreLocation manager used to request and track permission
    private let manager = CLLocationManager()
    
    // Published property indicating if the user has granted location access
    @Published var isAuthorized: Bool = false
    
    // MARK: - Initializer
    /// Private initializer for singleton pattern.
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    // MARK: - Permission Request
    /// Requests location permission from the user if not already determined.
    /// Updates `isAuthorized` based on current authorization status.
    func requestLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            // Ask the user for permission
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
        case .restricted, .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    /// Called whenever the location authorization status changes.
    /// Updates the `isAuthorized` published property accordingly.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
}
