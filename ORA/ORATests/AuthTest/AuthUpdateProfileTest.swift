import XCTest
@testable import ORA

/// `updateProfile` has an early- eturn optimization when nothing actually changes
/// (no renamed displayName and no new avatar).
final class AuthUpdateProfileTest: XCTestCase {

    func test_updateProfile_noChanges_callsCompletionNil_andReturns() {
        // Arrange: existing user named "Alice", we pass same name & no avatar
        let sut = AuthManager()
        sut.currentUser = User(id: "U1", username: "Alice", email: "a@b.c",
                               savedCafes: [], visitedCafes: [], pinnedCafes: [],
                               location: nil, profilePhotoUrl: nil, createdAt: .init())
        let done = expectation(description: "completion")

        // Act
        sut.updateProfile(displayName: "Alice", avatarData: nil) { err in
            // Assert
            XCTAssertNil(err)
            done.fulfill()
        }

        wait(for: [done], timeout: 1.0)
    }
}
