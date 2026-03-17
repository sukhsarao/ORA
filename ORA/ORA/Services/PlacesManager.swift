import GooglePlaces
import CoreLocation

// MARK: - Place Info Model
/// Represents the details of a place (cafe) retrieved from Google Places.
struct PlaceInfo {
    var name: String            // Name of the cafe
    var address: String         // Full formatted address
    var latitude: Double        // Latitude coordinate
    var longitude: Double       // Longitude coordinate
    var rating: Double?         // Optional rating (1-5)
    var photoURLs: [URL]        // Array of local URLs pointing to downloaded photos
}

// MARK: - Places Manager
/// Handles fetching place details (cafes, shops, etc.) using the Google Places SDK.
class PlacesManager {
    
    /// Shared Google Places client
    private let client = GMSPlacesClient.shared()
    
    // MARK: - Fetch Place Details
    /// Fetches detailed information for a cafe based on its name.
    /// - Parameters:
    ///   - cafeName: Name of the cafe to search for.
    ///   - completion: Completion block returning a `PlaceInfo` object or nil if not found.
    func fetchPlaceDetails(for cafeName: String, completion: @escaping (PlaceInfo?) -> Void) {
        
        // Filter to only return establishments (cafes, shops, etc.)
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        
        // Step 1: Autocomplete search for the cafe name
        client.findAutocompletePredictions(fromQuery: cafeName, filter: filter, sessionToken: nil) { predictions, error in
            guard let prediction = predictions?.first, error == nil else {
                completion(nil)
                return
            }
            
            // Step 2: Fetch detailed place info using place ID
            let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate, .rating, .photos]
            self.client.fetchPlace(fromPlaceID: prediction.placeID,
                                   placeFields: fields,
                                   sessionToken: nil) { place, error in
                guard let place = place, error == nil else {
                    completion(nil)
                    return
                }
                
                // Step 3: Load up to 3 photos, save them locally, and generate URLs
                var urls: [URL] = []
                if let photos = place.photos {
                    let group = DispatchGroup()
                    for metadata in photos.prefix(3) {
                        group.enter()
                        self.client.loadPlacePhoto(metadata) { image, error in
                            if let image = image {
                                // Convert image to JPEG and save to temporary directory
                                if let data = image.jpegData(compressionQuality: 0.8) {
                                    let filename = UUID().uuidString + ".jpg"
                                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                                    try? data.write(to: url)
                                    urls.append(url)
                                }
                            }
                            group.leave()
                        }
                    }
                    // Wait for all photos to load before calling completion
                    group.notify(queue: .main) {
                        completion(PlaceInfo(
                            name: place.name ?? cafeName,
                            address: place.formattedAddress ?? "",
                            latitude: place.coordinate.latitude,
                            longitude: place.coordinate.longitude,
                            rating: Double(place.rating),
                            photoURLs: urls
                        ))
                    }
                } else {
                    // No photos available, return basic info
                    completion(PlaceInfo(
                        name: place.name ?? cafeName,
                        address: place.formattedAddress ?? "",
                        latitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude,
                        rating: Double(place.rating),
                        photoURLs: []
                    ))
                }
            }
        }
    }
}
