import XCTest
@testable import ORA


///  Unit-tests for UnsplashClient (an actor) without real HTTP traffic.
///  We verify:
///  - Authorization header is present 
///  - JSON parsing (results[0].urls.small / thumb)
///  - Prefetch term -> URL mapping
///
///  How networking is mocked
///  ------------------------
///  setUp() registers MockURLProtocol so URLSession.shared routes here.
///  Each test sets MockURLProtocol.handler, which returns a fake HTTP response.
///  tearDown() clears the handler to avoid cross-test interference.

final class UnsplashClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Route URLSession.shared through our fake protocol...
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    
    override func tearDown() {
        super.tearDown()
        // Clear the handler so tests don’t leak state.
        MockURLProtocol.handler = nil
    }

    
    // Build a tiny Unsplash like JSON blob we can return from the mock.
    private func unsplashJSONResult(small: String, thumb: String? = nil) -> Data {
        let t = thumb ?? small
        let json = """
        { "results": [ { "urls": { "thumb": "\(t)", "small": "\(small)" } } ] }
        """
        return Data(json.utf8)
    }

    
    
    // Empty/whitespace query -> no network, returns nil.
    func test_url_for_emptyTerm_returnsNil_withoutNetwork() async throws {
        // Purpose:
        // Guard the fast-fail path: an all-whitespace term should be normalized to empty,
        // skip any HTTP work, and return nil immediately.

        // Arrange: if a network call happens by mistake, flip `called = true`
        var called = false
        MockURLProtocol.handler = { req in
            called = true
            let resp = HTTPURLResponse(url: req.url!,
                                       statusCode: 500,
                                       httpVersion: nil,
                                       headerFields: nil)!
            return (resp, nil)
        }

        // Act
        let client = UnsplashClient()
        let res = await client.url(for: "   ") // whitespace only

        // Assert: no URL and (critically) no network traffic
        XCTAssertNil(res, "Whitespace-only queries should short-circuit to nil")
        XCTAssertFalse(called, "Should not call network for empty/whitespace term")
    }


    
    
    // Sends Authorization header and parses urls.small from JSON.
    func test_url_successfulFetch() async throws {
        // Purpose:
        // Ensure we include the required Unsplash auth header
        // and correctly parse the first image URL from the response.

        // Arrange: capture the header and sanity-check the endpoint/query
        var capturedAuth: String?
        MockURLProtocol.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            let url = req.url!
            XCTAssertTrue(
                url.absoluteString.starts(with: "https://api.unsplash.com/search/photos?query=latte"),
                "Unexpected endpoint: \(url)"
            )
            let resp = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            // Return minimal JSON containing the URL we expect to parse
            return (resp, self.unsplashJSONResult(small: "https://img/latte-small.jpg"))
        }

        // Act: call the API exactly like production code does
        let client = UnsplashClient()
        let out = await client.url(for: "latte")

        // Assert: parsed URL + proper auth header
        XCTAssertEqual(out?.absoluteString, "https://img/latte-small.jpg",
                       "Should parse urls.small from the payload")
        XCTAssertNotNil(capturedAuth, "Authorization header must be present")
        XCTAssertTrue(capturedAuth!.hasPrefix("Client-ID "),
                      "Auth header must start with 'Client-ID '")
    }


    
    
    
    
    // Same normalized term twice -> first call hits the network, second is served from cache.
    func test_url_usesCache_secondCallDoesNotHitNetwork() async throws {
        //arrange
        // Count how many times our stubbed network layer is invoked.
        var calls = 0
        MockURLProtocol.handler = { req in
            calls += 1
            let resp = HTTPURLResponse(
                url: req.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            // Always return the same image URL so we can compare outputs.
            return (resp, self.unsplashJSONResult(small: "https://img/capp-small.jpg"))
        }

        // SUT
        let client = UnsplashClient()

        // Act: logically the same query (trim/case differ) -> should normalize to one cache key.
        let first  = await client.url(for: "cappuccino")       // expected: network call
        let second = await client.url(for: "  Cappuccino  ")   // expected: cache hit

        // Assert: both calls resolve to the same URL...
        XCTAssertEqual(first?.absoluteString,  "https://img/capp-small.jpg")
        XCTAssertEqual(second?.absoluteString, "https://img/capp-small.jpg")

        //and only one real request was made.
        XCTAssertEqual(calls, 1, "Second lookup should be served from cache, not the network")
    }


}
