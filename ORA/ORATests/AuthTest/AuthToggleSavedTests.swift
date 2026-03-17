import XCTest
@testable import ORA


/// `toggleSavedCafe(cafeId:)` is local state logic that:
/// - adds an ID if it’s not in `currentUser.savedCafes`,
/// - removes it if it is,
/// - then calls `updateSavedCafes(_:)`.
///
/// We *don’t* want these unit tests to hit Firestore, so we override
/// `updateSavedCafes(_:)` and just capture the value
final class AuthToggleSavedTests: XCTestCase {

    /// - Captures the most recent `savedCafes` payload in `lastSaved`.
    /// - Mirrors the production side effect of updating `currentUser?.savedCafes`
    ///   so UI bindings would behave the same in tests.
    /// - Avoids any network/Firestore work.
    private final class TestAuthManager: AuthManager {
        var lastSaved: [String] = []

        override func updateSavedCafes(_ cafeIds: [String]) {
            // Record what would have been sent to Firestore
            lastSaved = cafeIds
            // Mirror production side effect so tests can assert UI facing state
            self.currentUser?.savedCafes = cafeIds
        }

        // Keep the base init but we’re not relying on any listeners in these tests.
        override init() { super.init() }
    }

    /// Adds when missing:
    /// Start with no saved cafes, toggle once -> the ID appears in both
    /// the captured payload (`lastSaved`) and the in-memory user (`currentUser.savedCafes`).
    func test_addsWhenMissing() {
        // Arrange
        let sut = TestAuthManager()
        sut.currentUser = User(id: "U1", username: "t", email: "t@e.st",
                               savedCafes: [], visitedCafes: [], pinnedCafes: [],
                               location: nil, profilePhotoUrl: nil, createdAt: .init())

        // Act
        sut.toggleSavedCafe(cafeId: "cafe-42")

        // Assert
        XCTAssertEqual(sut.lastSaved, ["cafe-42"])
        XCTAssertEqual(sut.currentUser?.savedCafes, ["cafe-42"])
    }

    /// Removes when present:
    /// Start with two IDs saved, toggle one -> it’s removed and the other remains.
    func test_removesWhenPresent() {
        // Arrange
        let sut = TestAuthManager()
        sut.currentUser = User(id: "U1", username: "t", email: "t@e.st",
                               savedCafes: ["cafe-42", "cafe-7"], visitedCafes: [], pinnedCafes: [],
                               location: nil, profilePhotoUrl: nil, createdAt: .init())

        // Act
        sut.toggleSavedCafe(cafeId: "cafe-42")

        // Assert (order doesn’t matter)
        XCTAssertEqual(Set(sut.lastSaved), ["cafe-7"])
        XCTAssertEqual(Set(sut.currentUser?.savedCafes ?? []), ["cafe-7"])
    }

    /// Idempotence (add then remove):
    /// Toggling the same ID twice should bring us back to empty.
    func test_idempotentAddThenRemove_resultsEmpty() {
        // Arrange
        let sut = TestAuthManager()
        sut.currentUser = User(id: "U1", username: "t", email: "t@e.st",
                               savedCafes: [], visitedCafes: [], pinnedCafes: [],
                               location: nil, profilePhotoUrl: nil, createdAt: .init())

        // Act
        sut.toggleSavedCafe(cafeId: "c1") // add
        sut.toggleSavedCafe(cafeId: "c1") // remove

        // Assert
        XCTAssertEqual(sut.lastSaved, [])
        XCTAssertEqual(sut.currentUser?.savedCafes, [])
    }

    /// Safety when no user:
    /// If `currentUser` is nil, toggling is a no-op:
    /// - does not crash,
    /// - does not call `updateSavedCafes(_:)`.
    func test_noCurrentUser_isNoOp() {
        // Arrange
        let sut = TestAuthManager()
        sut.currentUser = nil

        // Act
        sut.toggleSavedCafe(cafeId: "c1")

        // Assert
        XCTAssertTrue(sut.lastSaved.isEmpty, "Should not attempt to update without a user")
        XCTAssertNil(sut.currentUser)
    }
}
