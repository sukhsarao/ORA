import XCTest
@testable import ORA


/// Our UI renders human friendly relative timestamps in many places (e.g. memory tiles and
/// preview overlays). Those strings come from two small helpers we wrote:
///
///   RelativeDateTimeFormatter.shortString(from:)
///   RelativeDateTimeFormatter.fullString(from:)
///
/// They look simple, but they are easy to subtly break . If these helpers miss, the UI can show something like “in -1 hr”
/// or empty strings across the app.
///
/// What we’re testing
/// ------------------
/// 1) Past timestamps produce non empty text and short vs full styles
/// 2) Distinct past instants render differently.
/// 3) Extreme values (.distantPast) don’t crash and still yield text.


final class RelativeDateStringTests: XCTestCase {


    /// Past timestamps should render as non-empty strings short/full styles should differ.
    func test_pastTimes_produceNonEmpty_andShortVsFullDiffer() {
        // Arrange: choose times safely in the past so wall clock drift can’t flip them to “future”.
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)

        // Act
        let s1 = RelativeDateTimeFormatter.shortString(from: oneHourAgo)
        let f1 = RelativeDateTimeFormatter.fullString(from: oneHourAgo)
        let s2 = RelativeDateTimeFormatter.shortString(from: twoHoursAgo)
        let f2 = RelativeDateTimeFormatter.fullString(from: twoHoursAgo)

        // Assert: helpers never return empty strings
        XCTAssertFalse(s1.isEmpty); XCTAssertFalse(f1.isEmpty)
        XCTAssertFalse(s2.isEmpty); XCTAssertFalse(f2.isEmpty)

        // Assert: (short vs full shouldn’t be identical)
        XCTAssertNotEqual(s1, f1)
        XCTAssertNotEqual(s2, f2)

        // Assert: distinct past instants should not collapse to the same label
        XCTAssertNotEqual(s1, s2)
        XCTAssertNotEqual(f1, f2)
    }

    
    
    
    
    /// Purpose:
    /// Stress an extreme input formatter shouldn’t crash or return nothing.
    /// Relevance:
    /// If bad data slips in (e.g., missing timestamps defaulting to extremes),
    /// the UI should handle very gracefully
    func test_extremePast_doesNotCrash_andProducesText() {
        // Act
        let s = RelativeDateTimeFormatter.shortString(from: .distantPast)
        let f = RelativeDateTimeFormatter.fullString(from: .distantPast)

        // Assert
        XCTAssertFalse(s.isEmpty)
        XCTAssertFalse(f.isEmpty)
    }
}
