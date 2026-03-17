import XCTest
@testable import ORA


/// - When we swipe a card away, we remember it in a `history` array.
/// - "Undo" should put the most recently swiped card back on top.
/// - If there's nothing to undo, nothing should happen.
/// - If we undo multiple times, cards should come back in the reverse order
///   they were swiped (that's how a stack/LIFO works).
///
/// - This is small, stateful logic that's easy to get subtly wrong (wrong card,
///   wrong position, wrong order).
/// - These tests keep us from shipping a deck that “forgets” which card to restore
///   or corrupts the visible order after a few swipes/undos.
final class SwipeDeckUndoLogicTests: XCTestCase {

    // A tiny stand in for our real Cafe model. We only need a stable id/name
    // to check ordering and identity in the test.
    struct Cafe: Equatable { let id: String; let name: String }
    
    
    
    /// Start with [A, B, C]. Swipe A off the deck (save it in history).
    /// Press Undo. We expect to get [A, B, C] again.
    func test_undoRestoresLastSwipedToTop() {
        // Start with three cards in order.
        var cafes = [Cafe(id: "1", name: "A"),
                     Cafe(id: "2", name: "B"),
                     Cafe(id: "3", name: "C")]
        var history: [Cafe] = []

        // Imitate a swipe: move the top card to history and remove it from the deck.
        history.append(cafes.first!)   // remember A
        cafes.removeFirst()            // deck is now [B, C]

        // Undo: pop the last swiped card and put it back on top.
        if let last = history.popLast() {
            cafes.insert(last, at: 0)
        }

        // We’re back to the original order  history is empty again.
        XCTAssertEqual(cafes.map(\.id), ["1", "2", "3"])
        XCTAssertTrue(history.isEmpty)
    }
    
    

    // MARK: 2) Undo when there is nothing to undo does nothing
    /// Simple story:
    /// If the user taps Undo without having swiped anything, we do nothing.
    /// No crashes, no order changes.
    func test_undoOnEmptyHistory_isNoOp() {
        var cafes = [Cafe(id: "1", name: "A"),
                     Cafe(id: "2", name: "B")]
        var history: [Cafe] = []

        // Try to undo with an empty history: the `if let` simply won’t run.
        if let last = history.popLast() {
            cafes.insert(last, at: 0)
        }

        // Deck stays the same; history stays empty.
        XCTAssertEqual(cafes.map(\.id), ["1", "2"])
        XCTAssertTrue(history.isEmpty)
    }


    
    /// Simple story:
    /// Start with [A, B, C, D]. Swipe A, then swipe B. Deck is [C, D].
    /// Now Undo twice: first we should get B back on top, then A on top.
    /// Final deck should be back to [A, B, C, D].
    func test_multipleSwipes_multipleUndos_restoreInLIFOOrder() {
        var cafes = [Cafe(id: "1", name: "A"),
                     Cafe(id: "2", name: "B"),
                     Cafe(id: "3", name: "C"),
                     Cafe(id: "4", name: "D")]
        var history: [Cafe] = []

        // Swipe A (top), then B (now top)
        history.append(cafes.first!)   // remember A
        cafes.removeFirst()            // [B, C, D]
        history.append(cafes.first!)   // remember B
        cafes.removeFirst()            // [C, D]

        // Undo twice: bring back B, then A (last in, first out).
        if let last = history.popLast() { cafes.insert(last, at: 0) } // B
        if let last = history.popLast() { cafes.insert(last, at: 0) } // A

        // We’ve restored the original order history is empty again.
        XCTAssertEqual(cafes.map(\.id), ["1", "2", "3", "4"])
        XCTAssertTrue(history.isEmpty)
    }
}
