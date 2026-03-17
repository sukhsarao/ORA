import WidgetKit
import SwiftUI
import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - Timeline Entry
/// Represents a single snapshot of data for the widget at a given date.
struct TrendingCafeEntry: TimelineEntry {
    let date: Date
    let cafe: Cafe
}

// MARK: - Timeline Provider
/// Provides data for the widget timeline.
struct TrendingCafeProvider: TimelineProvider {
    
    /// Placeholder entry shown in widget gallery or before data loads.
    func placeholder(in context: Context) -> TrendingCafeEntry {
        return TrendingCafeEntry(
            date: Date(),
            cafe: Cafe(
                id: "1",
                name: "Café Blue",
                imageUrl: nil,
                rating: 4.8,
                recents: [],
                specialsIDs: [],
                savesLast7Days: 12,
                lastSaveTimestamps: []
            )
        )
    }
    /// Snapshot for previewing the widget in SwiftUI previews.
    func getSnapshot(in context: Context, completion: @escaping (TrendingCafeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// Provides the timeline of entries for the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingCafeEntry>) -> Void) {
        let widgetCafes = loadTrendingCafes()

        // Generate timeline entries spaced by 10 seconds for demo purposes
        var entries: [TrendingCafeEntry] = []
        for (index, cafe) in widgetCafes.enumerated() {
            let entryDate = Date().addingTimeInterval(Double(index) * 10) // Switches the cafe every 10 seconds
            entries.append(
                TrendingCafeEntry(
                    date: entryDate,
                    cafe: Cafe(
                        id: cafe.id,
                        name: cafe.name,
                        imageUrl: cafe.imageUrl,
                        latitude: cafe.latitude,
                        longitude: cafe.longitude,
                        rating: cafe.rating,
                        recents: [],
                        specialsIDs: [],
                        savesLast7Days: cafe.savesLast7Days,
                        lastSaveTimestamps: []
                    )
                )
            )
        }

        // Schedule next update in 2 minutes
        let nextUpdate = Date().addingTimeInterval(120)
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }

    // MARK: - Data Loading
    /// Loads trending cafés from shared container plist.
    /// Returns an empty array if the file is missing or cannot be decoded.
    private func loadTrendingCafes() -> [WidgetCafe] {
        // Gets the container url
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.ORA.cafe.finder.shared"
        ) else {
            print("Shared container not found")
            return []
        }
        // Decode the trending cafes from the plist
        let fileURL = containerURL.appendingPathComponent("trendingCafes.plist")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Trending cafés plist not found")
            return []
        }
        // Load the trending cafes after decoding
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try PropertyListDecoder().decode(CafeList.self, from: data)
            return decoded.cafes
        } catch {
            print("Failed to decode trending cafés: \(error)")
            return []
        }
    }
}

// MARK: - Entry View
/// Displays a single trending café with image, name, rating, and distance.
struct TrendingCafeWidgetEntryView: View {
    var entry: TrendingCafeProvider.Entry
    
    @StateObject private var locationManager = WidgetLocationManager.shared
    @StateObject private var permissionManager = WidgetPermissionManager.shared
    @Environment(\.colorScheme) private var colorScheme

    // Compute user location if authorized
    private var userLocation: CLLocation? {
        guard permissionManager.isAuthorized else { return nil }
        return locationManager.currentLocation
    }

    // Color scheme for widget checks if envirnment is in dark mode or light
    private var dynamicTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack {
            // Background image or placeholder color
            if let urlString = entry.cafe.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.25))
                        .ignoresSafeArea()
                } placeholder: {
                    Color("Widget").ignoresSafeArea()
                }
            } else {
                Color("Widget").ignoresSafeArea()
            }
            
            // Overlay content
            VStack {
                // General logo and text
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(dynamicTextColor.opacity(0.8))
                    
                    Text("Trending Cafés")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(dynamicTextColor.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
                VStack(spacing: 4) {
                    // Show the cafe name
                    Text(entry.cafe.name)
                        .font(.system(size: 21, weight: .semibold))
                        .lineLimit(2)
                        .foregroundColor(dynamicTextColor)
                        .shadow(radius: 4)
                        .multilineTextAlignment(.center)
                    // Present Rating of cafe
                    HStack {
                        Rating(rating: entry.cafe.rating ?? 0.0, fgColor: dynamicTextColor)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    
                    // Show distance if possible from user location to cafe
                    if let lat = entry.cafe.latitude,
                       let lon = entry.cafe.longitude,
                       let userLoc = userLocation {
                        Text(distanceString(from: userLoc,
                                            to: CLLocation(latitude: lat, longitude: lon)))
                            .font(.caption)
                            .foregroundColor(dynamicTextColor.opacity(0.85))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Distance unknown")
                            .font(.caption)
                            .foregroundColor(dynamicTextColor.opacity(0.5))
                    }
                }
                .padding()
            }
        }
        .onAppear {
            permissionManager.requestLocationPermission() // Permissions managers to request location permission
            locationManager.requestLocation() // Request actual location
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .containerBackground(for: .widget) { Color("Widget") }
    }
}

// MARK: - Widget Configuration
struct TrendingCafeWidget: Widget {
    let kind: String = "TrendingCafeWidget"
    // Widgets configuration
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrendingCafeProvider()) { entry in
            TrendingCafeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Trending Cafés")
        .description("See Melbourne’s top trending cafés.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
