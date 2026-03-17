import CoreLocation
import WidgetKit
import Combine

// MARK: - Shared Location Manager
/// Singleton class to manage user location updates and permissions.
/// Publishes the current location and authorization status for use in SwiftUI views or widgets.
class SharedLocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    /// Shared singleton instance
    static let shared = SharedLocationManager()
    
    private let manager = CLLocationManager()
    
    /// Published current location
    @Published var currentLocation: CLLocation?
    
    /// Published authorization status
    @Published var isAuthorized: Bool = false
    
    /// Private initializer to enforce singleton
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        checkAuthorizationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Requests the current location from the location manager
    func requestLocation() {
        manager.requestLocation()
    }
    
    /// Requests location permission from the user if not determined
    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            checkAuthorizationStatus()
        }
    }
    
    /// Checks the current authorization status and updates `isAuthorized`
    private func checkAuthorizationStatus() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    /// Called when the location manager provides new location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        // Reload widgets when location changes
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Called when the authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorizationStatus()
    }
    
    /// Called when location updates fail
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location update failed:", error.localizedDescription)
    }
}

// MARK: - Distance Helper
/// Computes a human-readable string for distance between the user and a cafe
/// - Parameters:
///   - userLocation: Optional user's current location
///   - cafeLocation: The location of the cafe
/// - Returns: Distance string in meters or kilometers
func distanceString(from userLocation: CLLocation?, to cafeLocation: CLLocation) -> String {
    guard let userLoc = userLocation else { return "Location unavailable" }
    
    let distanceMeters = userLoc.distance(from: cafeLocation)
    
    if distanceMeters < 1000 {
        return "\(Int(distanceMeters)) m away"
    } else {
        return String(format: "%.1f km away", distanceMeters / 1000)
    }
}
