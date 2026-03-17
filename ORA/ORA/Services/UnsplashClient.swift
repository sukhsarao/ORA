import Foundation

/// A client for fetching Unsplash images by search term, with caching and prefetching.
actor UnsplashClient {

    /// Shared singleton instance.
    static let shared = UnsplashClient()

    /// Unsplash API access key from `Secrets`.
    private let accessKey: String = Secrets.unsplashAccessKey

    /// In-memory cache to avoid redundant API calls.
    private var cache: [String: URL?] = [:]

    // MARK: - Single Image Fetch

    /// Fetches one Unsplash image URL for a given search term.
    /// - Parameter term: The search term.
    /// - Returns: The image URL if available; otherwise `nil`.
    func url(for term: String) async -> URL? {
        let key = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Return cached result if available
        if let hit = cache[key] { return hit }
        
        // Validate access key and construct request URL
        guard !accessKey.isEmpty,
              !key.isEmpty,
              let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.unsplash.com/search/photos?query=\(encoded)&per_page=1") else {
            cache[key] = nil
            return nil
        }

        // Add authorization header
        var req = URLRequest(url: url)
        req.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")

        do {
            // Perform API call
            let (data, resp) = try await URLSession.shared.data(for: req)
            
            // Validate HTTP response
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                cache[key] = nil
                return nil
            }
            
            // Decode JSON and extract image URL
            let decoded = try JSONDecoder().decode(UnsplashSearch.self, from: data)
            let link = decoded.results.first?.urls.small ?? decoded.results.first?.urls.thumb
            let u = link.flatMap(URL.init(string:))

            // Cache and return
            cache[key] = u
            return u
        } catch {
            // Cache failure result
            cache[key] = nil
            return nil
        }
    }

    // MARK: - Prefetching

    /// Prefetches images for multiple search terms concurrently.
    /// - Parameters:
    ///   - terms: Array of search terms.
    ///   - maxConcurrent: Maximum number of concurrent fetches.
    /// - Returns: A dictionary mapping term to fetched URL or `nil`.
    func prefetch(_ terms: [String], maxConcurrent: Int = 4) async -> [String: URL?] {
        var out: [String: URL?] = [:]

        // Deduplicate and sanitize terms
        let unique = Array(Set(terms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }

        // Limit concurrent fetches using a task group
        await withTaskGroup(of: (String, URL?).self) { group in
            var pending = ArraySlice(unique)
            var running = 0

            func launch(_ t: String) {
                running += 1
                group.addTask { (t, await self.url(for: t)) }
            }

            // Start initial batch
            while running < maxConcurrent, let t = pending.popFirst() {
                launch(t)
            }

            // As tasks finish, launch next ones
            for await (t, u) in group {
                out[t] = u
                running -= 1
                if let next = pending.popFirst() { launch(next) }
            }
        }

        return out
    }

    // MARK: - Minimal Unsplash Response Models

    /// Minimal models to decode Unsplash API response.
    private struct UnsplashSearch: Decodable {
        let results: [Photo]

        struct Photo: Decodable {
            let urls: Urls
            struct Urls: Decodable { let thumb: String; let small: String }
        }
    }
}
