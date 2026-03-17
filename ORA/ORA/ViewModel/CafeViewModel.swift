//
//  fetchCafes.swift
//  ORA
//
//  Created by Sukhman Singh on 25/9/2025.
//

import FirebaseFirestore
import WidgetKit

/// A view model responsible for fetching, enriching, and caching café data from Firestore.
class CafeViewModel: ObservableObject {
    /// The list of cafés displayed in the app.
    @Published var cafes: [Cafe] = []
    
    /// The Firestore database reference.
    private var db = Firestore.firestore()
    
    /// Manages place enrichment such as address, location, and rating.
    private let placesManager = PlacesManager()
    
    // MARK: - Café Fetching
    
    /// Fetches all cafés from Firestore, including specials and Google Places enrichment.
    ///
    /// The method:
    /// 1. Retrieves all café documents from Firestore.
    /// 2. Fetches associated menu specials for each café.
    /// 3. Enriches each café with address, coordinates, and rating from Google Places.
    /// 4. Saves trending cafés to the shared container for widget access.
    func fetchCafes() {
        db.collection("cafes").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else {
                print("fetchCafes: error fetching cafes:", error ?? "unknown")
                return
            }
            
            var cafes: [Cafe] = []
            let outerGroup = DispatchGroup()
            
            for doc in docs {
                outerGroup.enter()
                
                // Decode café document
                var cafe: Cafe
                if let decoded = try? doc.data(as: Cafe.self) {
                    cafe = decoded
                } else {
                    let data = doc.data()
                    cafe = Cafe(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        imageUrl: data["imageUrl"] as? String,
                        amenities: data["amenities"] as? [String],
                        createdAt: nil,
                        address: data["address"] as? String,
                        latitude: data["latitude"] as? Double,
                        longitude: data["longitude"] as? Double,
                        rating: data["rating"] as? Double,
                        imageURLs: nil,
                        specials: [],
                        recents: data["recents"] as? [String],
                        specialsIDs: data["specials"] as? [String] ?? []
                    )
                }
                
                // Fetch menu specials ID's if present
                if cafe.specialsIDs.isEmpty {
                    cafes.append(cafe)
                    outerGroup.leave()
                } else {
                    let specialsGroup = DispatchGroup()
                    var fetchedSpecials: [MenuItem] = [] // No specials exist
                    
                    // Get the full menu item based on the specials ID's
                    for menuId in cafe.specialsIDs {
                        specialsGroup.enter()
                        let subDocRef = self.db.collection("cafes").document(doc.documentID).collection("menus").document(menuId)
                        subDocRef.getDocument { subSnap, subErr in
                            defer { specialsGroup.leave() }
                            if let subSnap = subSnap, subSnap.exists, subErr == nil {
                                if let menu = try? subSnap.data(as: MenuItem.self) {
                                    fetchedSpecials.append(menu)
                                } else {
                                    let d = subSnap.data() ?? [:]
                                    // Create a Menu item with the fetched data
                                    let menu = MenuItem(
                                        id: subSnap.documentID,
                                        name: d["name"] as? String ?? "Unknown",
                                        imageUrl: d["imageUrl"] as? String,
                                        description: d["description"] as? String,
                                        price: d["price"] as? String,
                                        sizes: d["sizes"] as? [String: String],
                                        type: d["type"] as? String ?? "food"
                                    )
                                    fetchedSpecials.append(menu)
                                }
                            }
                        }
                    }
                    
                    specialsGroup.notify(queue: .main) {
                        cafe.specials = fetchedSpecials
                        cafes.append(cafe)
                        outerGroup.leave()
                    }
                }
            }
            
            // Enrich cafés with Google Places data
            outerGroup.notify(queue: .main) {
                print("fetchCafes: loaded \(cafes.count) cafes, now fetching Places data...")
                let placesGroup = DispatchGroup()
                // Enter the google places api and fetch the address, rating, photos and long/lat
                for i in cafes.indices {
                    placesGroup.enter()
                    let cafe = cafes[i]
                    self.placesManager.fetchPlaceDetails(for: cafe.name) { info in
                        defer { placesGroup.leave() }
                        guard let info = info else { return }
                        DispatchQueue.main.async {
                            cafes[i].address = info.address
                            cafes[i].latitude = info.latitude
                            cafes[i].longitude = info.longitude
                            cafes[i].rating = info.rating
                            cafes[i].imageURLs = info.photoURLs
                        }
                    }
                }
                // Finish enriching
                placesGroup.notify(queue: .main) {
                    self.cafes = cafes.shuffled() // Shuffle the cafes randomly for the Swipe deck
                    print("fetchCafes: all cafes enriched with Places data.")
                    self.saveCafesToSharedContainer() // For the widget
                    print("Saved to shared Container")
                }
            }
        }
    }
    
    // MARK: - Menu Fetching
    
    /// Fetches all menu items for a given café.
    /// - Parameters:
    ///   - cafeId: The Firestore café document ID.
    ///   - completion: A closure returning an array of `MenuItem` objects.
    func fetchMenus(for cafeId: String, completion: @escaping ([MenuItem]) -> Void) {
        
        // fetch the menus
        db.collection("cafes").document(cafeId).collection("menus").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching menus: \(error)")
                completion([])
                return
            }
            // Menus list that contain a list of menu items for a cafe
            var menus: [MenuItem] = []
            let docs = snapshot?.documents ?? []
            
            // decode the item
            for doc in docs {
                if let decoded: MenuItem? = try? doc.data(as: MenuItem.self), let item = decoded {
                    menus.append(item)
                    continue
                }
                // If the Menu items name does not exist then skip
                let data = doc.data()
                guard let name = data["name"] as? String else {
                    print("Missing name for menu item \(doc.documentID), skipping")
                    continue
                }
                
                // Get the menu items detail
                let imageUrl = data["imageUrl"] as? String
                let description = data["description"] as? String
                let type = data["type"] as? String ?? "food"
                
                // Convert price to string if needed
                var priceString: String? = nil
                if let p = data["price"] as? String {
                    priceString = p
                } else if let p = data["price"] as? Double {
                    priceString = String(p)
                } else if let p = data["price"] as? Int {
                    priceString = String(p)
                }
                
                // Normalize sizes dictionary
                var sizesDict: [String: String]? = nil
                if let rawSizes = data["sizes"] as? [String: Any] {
                    var mapped: [String: String] = [:]
                    for (k, v) in rawSizes {
                        mapped[k.lowercased()] = "\(v)"
                    }
                    if !mapped.isEmpty { sizesDict = mapped }
                }
                // Create a menu item
                let item = MenuItem(
                    id: doc.documentID,
                    name: name,
                    imageUrl: imageUrl,
                    description: description,
                    price: priceString,
                    sizes: sizesDict,
                    type: type
                )
                // Add item to menus
                menus.append(item)
            }
            // Finish
            completion(menus)
        }
    }
    
    // MARK: - Trending cafes for Widget
    /// Saves trending cafés to the shared app group container for use by widgets.
    ///
    /// Encodes the top cafés as a property list and stores it in the shared container,
    /// then triggers a timeline reload in `WidgetCenter`.
    private func saveCafesToSharedContainer() {
        
        // get the trending cafes from the Utils function
        let trendingCafes = CafeUtils.getTrendingCafes(from: cafes, count: 4)
        do {
            // Create a widget cafe: differes from cafe model as firestore Document Id causes issues in shared app groups
            let widgetCafes = trendingCafes.map {
                WidgetCafe(
                    id: $0.id ?? UUID().uuidString,
                    name: $0.name,
                    imageUrl: $0.imageUrl,
                    rating: $0.rating,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    savesLast7Days: $0.savesLast7Days
                )
            }
            // List of cafes
            let cafeList = CafeList(cafes: widgetCafes)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(cafeList)
            
            // Share on group.com.ORA.cafe.finder.shared app group.
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.ORA.cafe.finder.shared"
            ) else {
                print("Could not get app group container URL.")
                return
            }
            
            // Wrtie trending cafes to shared plist file
            let fileURL = containerURL.appendingPathComponent("trendingCafes.plist")
            try data.write(to: fileURL, options: .atomic)
            // Share the trending cafes
            if let defaults = UserDefaults(suiteName: "group.com.ORA.cafe.finder.shared") {
                defaults.set(Date().timeIntervalSince1970, forKey: "trendingCafes_lastUpdated")
            }
            // Reload the widgets timeline
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Error saving trending cafés: \(error)")
        }
    }
}
