import Foundation
@testable import ORA

///  Purpose
///  -------
///  Replace real networking in tests by intercepting URLSession.shared requests.
///  Tests set `MockURLProtocol.handler` to decide what each request should return.
///
///  Usage
///  -----
///  1) In test setUp(): URLProtocol.registerClass(MockURLProtocol.self)
///  2) In each test:   MockURLProtocol.handler = { request in ... return (response, data) }
///  3) In tearDown():  MockURLProtocol.handler = nil
///
///  - Throw from the handler to simulate networking errors.
final class MockURLProtocol: URLProtocol {
    /// Test sets this to decide how each intercepted request should respond...
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    
    // Tell URLSession we can handle ALL requests...
     override class func canInit(with request: URLRequest) -> Bool { true }

    
    // Don’t modify the request just pass it through...
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    
    // Start the “fake” load..
    override func startLoading() {
        // If the test didn’t configure a handler, fail loudly..
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            // Ask the test how to respond to this request...
            let (response, data) = try handler(request)
            // Send back the HTTP response (status + headers)...
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            // If there’s a body, stream it to the client...
            if let data { client?.urlProtocol(self, didLoad: data) }
            // Signal that we’re done...
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // Simulate a networking error...
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    
    // Nothing to cancel/cleanup for our simple fake..
    override func stopLoading() {}
}
