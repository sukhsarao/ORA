import MapKit

// MARK: DistanceFormatter
/// Small helper to turn raw meters into compact, human readable strings
/// like "450 m" or "2.1 km".
///
enum DistanceFormatter {
    /// Shared MKDistanceFormatter so we don’t re-create one per call.
    static let shared: MKDistanceFormatter = {
        let f = MKDistanceFormatter()
        f.unitStyle = .abbreviated      // "m" / "km" with no long words
        f.units = .default              // iOS picks metric/imperial based on locale
        return f
    }()

    /// Converts a distance (in meters) into a short text string.
    static func string(from meters: CLLocationDistance) -> String {
        shared.string(fromDistance: meters)
    }
}




// MARK: RouteKey
/// A stable identifier for an on map route overlay.
///
/// We encode both the cafe id and the transport mode so that:
/// - switching modes (Walk/Drive) forces a rebuild,
/// - multiple routes can coexist without overwriting each other.
struct RouteKey: Hashable {
    /// Firestore/Model identifier for the cafe this route targets.
    let cafeID: String
    /// A compact tag for transport mode (e.g. "walk", "drive").
    let modeTag: String
}




// MARK: TransportMode
/// Supported transport modes for directions + overlays.
///
/// Keeps UI (labels), MapKit (MKDirectionsTransportType), and
/// overlay management (overlayTag) in one place.
enum TransportMode: String, CaseIterable, Identifiable, Hashable {
    case walking
    case driving

    /// Conform to Identifiable so we can use it in `Picker`.
    var id: Self { self }

    /// Short, user-facing label for UI controls.
    var label: String {
        self == .walking ? "Walk" : "Drive"
    }

    /// The MapKit transport type used when calculating routes.
    var mkType: MKDirectionsTransportType {
        self == .walking ? .walking : .automobile
    }

    /// A tiny string baked into overlay titles, so we can detect and  refresh the correct overlays when the mode changes.

    var overlayTag: String {
        self == .walking ? "walk" : "drive"
    }
}
