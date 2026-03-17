import XCTest
@testable import ORA

/// Our swipe UX decides whether to commit a "LIKE" or "NOPE" using a blended
/// displacement that includes both the drag distance and a fraction of the predicted
/// end displacement (velocity hint):
///
///     effective = dx + 0.25 * predictedDx
///     commit if abs(effective) > 120
///     liked  if effective > 0(by zero +ve)
///
/// Why this matters
/// ----------------
/// - If we ignore predictedDx, quick flicks will often fail to commit (feels broken).
/// - If we flip a sign, left swipes could become LIKEs the user won't be able to save it
/// - If we get the threshold wrong (>= vs >), the logic won't be happening correctly.
///
/// What we cover
/// -------------
/// 1) A rightward flick beyond the threshold commits a LIKE.
/// 2) A leftward flick beyond the threshold commits a NOPE.
/// 3) Small drags + weak velocity do not commit.
/// 4) Exactly on threshold does *not* commit
final class SwipeDecisionMathTests: XCTestCase {

    // Mirror of the production decision rule in SwipeCard.dragGesture():
    //   effective = dx + 0.25 * predictedDx
    //   commit if abs(effective) > threshold
    //   liked if effective > 0
    private func decision(dx: CGFloat,
                          predictedDx: CGFloat,
                          threshold: CGFloat = 120) -> (commit: Bool, liked: Bool) {
        let effective = dx + 0.25 * predictedDx
        let commit = abs(effective) > threshold
        return (commit, effective > 0)
    }
    
    
    

    /// Purpose:
    /// A modest right drag plus strong positive fling should commit a LIKE.
    /// Relevance:
    /// Validates that predicted velocity is included and sign handling is correct.
    func test_commit_like_whenEffectiveBeyondThreshold() {
        // effective = 40 + 0.25*400 = 140 (>120) -> commit LIKE
        let dx: CGFloat = 40
        let predicted: CGFloat = 400

        let out = decision(dx: dx, predictedDx: predicted)

        XCTAssertTrue(out.commit)
        XCTAssertTrue(out.liked)
    }

    
    
    /// Purpose:
    /// A strong left flick should cross the negative threshold and commit a NOPE.
    /// Relevance:
    /// Guards against sign inversions (“left swipes like”).
    func test_commit_nope_whenEffectiveBeyondNegativeThreshold() {
        // effective = -30 + 0.25*(-500) = -155 (<-120) -> commit NOPE
        let dx: CGFloat = -30
        let predicted: CGFloat = -500

        let out = decision(dx: dx, predictedDx: predicted)

        XCTAssertTrue(out.commit)
        XCTAssertFalse(out.liked)
    }

    
    
    /// Purpose:
    /// Small movements with weak velocity should *not* commit.
    /// Relevance:
    /// Prevents accidental likes/nopes when users are just peeking the card.
    func test_noCommit_whenEffectiveBelowThreshold() {
        // effective = 60 + 0.25*120 = 90 (<120) -> no commit
        let dx: CGFloat = 60
        let predicted: CGFloat = 120

        let out = decision(dx: dx, predictedDx: predicted)

        XCTAssertFalse(out.commit)
    }

    
    
    /// Purpose:
    /// The boundary is strictly '>'; hitting the threshold exactly should NOT commit.
    /// Relevance:
    /// Avoids off by one threshold bugs that make identical swipes behave inconsistently.
    func test_exactThreshold_doesNotCommit() {
        // effective = 80 + 0.25*160 = 120 (== threshold) -> should NOT commit
        let dx: CGFloat = 80
        let predicted: CGFloat = 160

        let out = decision(dx: dx, predictedDx: predicted)

        XCTAssertFalse(out.commit, "Commit must be strictly greater than the threshold.")
    }
}
