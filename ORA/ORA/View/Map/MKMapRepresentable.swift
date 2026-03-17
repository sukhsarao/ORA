import SwiftUI
import MapKit
import UIKit

// We bridge UIKit’s MKMapView into SwiftUI.
// - We render only *our* Pinned (red) and Trending (blue) cafes as markers.
// - If a cafe is both pinned and trending, we color it blue (trending wins).
// - We compute and draw routes from the user’s location to one or more cafes.
// - We tag route overlays as "Route:<cafeID>:<modeTag>" (e.g., "Route:abc123:walk") so we can quickly replace/remove the right overlay when transport mode changes
//   or when we switch which cafes are routed.
// - Tapping a marker routes to that single cafe and invokes `onTapCafe` so SwiftUI can navigate to the cafe detail screen.
//
// Data flow (one glance): SwiftUI (MapView) -:> MKMapRepresentable (this file) -> MKMapView (UIKit)
//   - We pass cafes, pinnedIDs, trendingIDs, routedCafeIDs, transport, userLocation
//   - Coordinator acts as MKMapViewDelegate and manages markers + overlays


// MARK: CafeAnnotation (UIKit model for pins)
/// Marker for a Cafe on MKMapView (no duplicate Cafe models used).
/// We keep the original `Cafe` so we can pass it back to SwiftUI on tap.
final class CafeAnnotation: NSObject, MKAnnotation {
    let cafe: Cafe
    let coordinate: CLLocationCoordinate2D
    var title: String? { cafe.name }

    /// Coloring rules: pinned -> red, trending -> blue (blue wins if both).
    var isPinned: Bool
    var isTrending: Bool

    init(cafe: Cafe, coordinate: CLLocationCoordinate2D, isPinned: Bool, isTrending: Bool) {
        self.cafe = cafe
        self.coordinate = coordinate
        self.isPinned = isPinned
        self.isTrending = isTrending
    }
}

// MARK: MKMapRepresentable (SwiftUI and UIKit bridge)
/// SwiftUI wrapper for MKMapView.
/// We receive the cafe set and routing state from SwiftUI and keep MKMapView in sync.
struct MKMapRepresentable: UIViewRepresentable {
    // We pass only pinned + trending cafés into this representable,
    // so annotation management can be simple and fast.
    @Binding var cafes: [Cafe]
    var pinnedIDs: Set<String>
    var trendingIDs: Set<String>

    // Routing state (single or multiple cafe ids).
    @Binding var routedCafeIDs: Set<String>

    // Current transport mode (walking/driving) to compute routes and tag overlays.
    var transport: TransportMode

    // Callback to open details when a marker is tapped.
    var onTapCafe: ((Cafe) -> Void)?

    // Optional current user location for directions and fitting route bounds.
    var userLocation: CLLocation?

    // Initial camera (Melbourne CBD).
    var initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // MARK: UIViewRepresentable
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .none
        map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CafeMarker")
        map.setRegion(initialRegion, animated: false)

        // Keep references on the coordinator so delegate methods can access them.
        context.coordinator.mapView = map
        context.coordinator.onTapCafe = onTapCafe
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // MARK: Annotations (sync pins with incoming cafes)
        // We compute the target annotations for the current cafe set, then diff against existing to add/remove efficiently.
        let existing = map.annotations.compactMap { $0 as? CafeAnnotation }
        let existingIDs = Set(existing.compactMap { $0.cafe.id })

        let target: [CafeAnnotation] = cafes.compactMap { cafe in
            guard let lat = cafe.latitude, let lon = cafe.longitude, let id = cafe.id else { return nil }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // If a cafe is both pinned and trending, we’ll render it blue in viewFor annotation.
            let pinned = pinnedIDs.contains(id)
            let trending = trendingIDs.contains(id)
            return CafeAnnotation(cafe: cafe, coordinate: coord, isPinned: pinned, isTrending: trending)
        }

        let targetIDs = Set(target.compactMap { $0.cafe.id })

        //remove annotations not in target
        map.removeAnnotations(existing.filter { $0.cafe.id.map { !targetIDs.contains($0) } ?? true })

        //add new annotations
        map.addAnnotations(target.filter { $0.cafe.id.map { !existingIDs.contains($0) } ?? false })

        // MARK: Routes (mode-aware overlays)
        //overlay titles use "Route:<cafeID>:<modeTag>" to track per-café + per mode.
        let overlays = map.overlays.compactMap { $0 as? MKPolyline }

        // Remove overlays for cafes we’re no longer routing OR for a different mode.
        let toRemove = overlays.filter { poly in
            guard let t = poly.title else { return true }
            let parts = t.split(separator: ":").map(String.init)
            guard parts.count == 3, parts[0] == "Route" else { return true }
            let cafeID = parts[1], modeTag = parts[2]
            return !routedCafeIDs.contains(cafeID) || modeTag != transport.overlayTag
        }
        map.removeOverlays(toRemove)

        // Add missing overlays for the current mode and current routed cafes.
        if let uloc = userLocation {
            // Build a quick set of existing (cafeID, modeTag) to avoid duplicate work.
            let existingKeys: Set<RouteKey> = Set(
                map.overlays.compactMap { overlay -> RouteKey? in
                    guard let poly = overlay as? MKPolyline, let t = poly.title else { return nil }
                    let parts = t.split(separator: ":").map(String.init)
                    guard parts.count == 3, parts[0] == "Route" else { return nil }
                    return RouteKey(cafeID: parts[1], modeTag: parts[2])
                }
            )

            // For every routed cafe, if its (id, mode) key is missing, compute the route.
            for id in routedCafeIDs {
                let key = RouteKey(cafeID: id, modeTag: transport.overlayTag)
                guard !existingKeys.contains(key),
                      let cafe = cafes.first(where: { $0.id == id }),
                      let lat = cafe.latitude, let lon = cafe.longitude
                else { continue }

                context.coordinator.buildRoute(
                    from: uloc.coordinate,
                    to: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    forCafeID: id,
                    modeTag: transport.overlayTag,
                    transportType: transport.mkType
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator (MKMapViewDelegate)
    /// We centralize all MKMapView delegate logic here:
    /// - Create and style annotation views (red for pinned, blue for trending).
    /// - Respond to marker taps (route to that cafe + open details).
    /// - Render route overlays with a consistent style.
    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: MKMapRepresentable
        weak var mapView: MKMapView?
        var onTapCafe: ((Cafe) -> Void)?

        init(_ parent: MKMapRepresentable) { self.parent = parent }

        // MARK: Annotation Views
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let ann = annotation as? CafeAnnotation else { return nil }

            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "CafeMarker", for: ann) as! MKMarkerAnnotationView
            v.canShowCallout = false
            // Coloring policy:
            // - Trending (blue) wins if both flags are true.
            // - Pinned only->  red.
            // - Neither (should be rare here) → gray.
            v.markerTintColor = ann.isTrending ? .systemBlue : (ann.isPinned ? .systemRed : .systemGray)
            v.glyphImage = UIImage(systemName: "cup.and.saucer.fill")
            return v
        }

        // MARK: Marker Tap
        // When we tap a marker:
        // - We route only to that cafe (single target).
        // - We compute the route for the current transport mode.
        // - We notify SwiftUI (`onTapCafe`) so it can present the cafe detail.
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? CafeAnnotation, let id = ann.cafe.id else { return }

            // Single-route behavior (tap = one route)
            parent.routedCafeIDs = [id]

            if let uloc = mapView.userLocation.location?.coordinate,
               let lat = ann.cafe.latitude, let lon = ann.cafe.longitude {
                buildRoute(
                    from: uloc,
                    to: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    forCafeID: id,
                    modeTag: parent.transport.overlayTag,
                    transportType: parent.transport.mkType
                )
            }

            onTapCafe?(ann.cafe)
        }

        // MARK: Overlay Renderer
        // We keep the route line slim and clean.
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: line)
            r.lineWidth = 2.0
            r.strokeColor = UIColor.systemBlue
            return r
        }

        // MARK: Route Builder
        // We remove any existing overlay for the café (any mode) and add a fresh one
        // tagged with the cafe id + current mode. That keeps the map state consistent
        // when we change which cafes we’re routing or switch transport modes.
        func buildRoute(from: CLLocationCoordinate2D,
                        to: CLLocationCoordinate2D,
                        forCafeID id: String,
                        modeTag: String,
                        transportType: MKDirectionsTransportType) {
            guard let map = mapView else { return }

            // Replace any existing route overlays for this cafe.
            for o in map.overlays {
                if let line = o as? MKPolyline, let t = line.title, t.contains("Route:\(id):") {
                    map.removeOverlay(line)
                }
            }

            // Standard MapKit directions request.
            let req = MKDirections.Request()
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            req.transportType = transportType
            req.requestsAlternateRoutes = false

            MKDirections(request: req).calculate { [weak map] resp, _ in
                guard let route = resp?.routes.first, let map = map else { return }
                let line = route.polyline
                line.title = "Route:\(id):\(modeTag)"
                map.addOverlay(line)

                // If this is the first overlay, we fit the camera to the route.
                if map.overlays.count == 1 {
                    let pad = UIEdgeInsets(top: 40, left: 28, bottom: 40, right: 28)
                    map.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: pad, animated: true)
                }
            }
        }
    }
}
