import SwiftUI

// MARK: - Swipe Deck
/// A Tinder-style swipeable deck of `SwipeCard`s.
///
/// Features:
/// - Loads cafes from bundled JSON on first appearance
/// - Shows top card interactively, next card slightly scaled
/// - Emits a callback when a card is swiped (liked/disliked)
/// - Supports Undo via a tick binding from the parent
struct SwipeDeck: View {
    
    /// Incrementing binding to trigger undo of last swipe
    @Binding var undoTick: Int
    
    /// ViewModel holding list of cafes
    @StateObject private var vm = CafeViewModel()
    
    /// Stack of previously swiped cafes for undo
    @State private var history: [Cafe] = []
    
    /// Progress of the top card swipe (0...1)
    @State private var topProgress: CGFloat = 0
    
    /// Flag indicating if cafes have loaded
    @State private var didLoad = false

    /// Callback when a cafe is swiped
    var onSwipedCafe: ((Cafe, Bool) -> Void)? = nil

    // MARK: - Body
    var body: some View {
        ZStack {
            // Render all cards in stack
            ForEach(Array(vm.cafes.enumerated()), id: \.element.id) { index, cafe in
                let isTop = index == 0
                let isNext = index == 1

                SwipeCard(
                    cafe: cafe,
                    onProgress: { p in if isTop { topProgress = p } },
                    onSwiped: { liked in
                        // Emit callback
                        onSwipedCafe?(cafe, liked)
                        
                        // Remove top card with animation and record in history
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            if let removed = vm.cafes.first { history.append(removed) }
                            _ = vm.cafes.removeFirst()
                            topProgress = 0
                        }
                    }
                )
                // Scale and offset for stacked effect
                .scaleEffect(isTop ? 1.0 : (isNext ? (0.96 + 0.04 * min(topProgress, 1)) : 0.96))
                .offset(y: isTop ? 0 : (isNext ? 12 - 12 * min(topProgress, 1) : 24))
                .allowsHitTesting(isTop) // Only top card is interactive
                .zIndex(Double(vm.cafes.count - index))
            }

            // Placeholder when no cards are left
            if vm.cafes.isEmpty {
                if !didLoad {
                    ProgressView("Loading cafes...")
                        .tint(AppColor.primary)
                } else {
                    Text("No more cafes nearby ☕️")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        // Undo action triggered by parent binding
        .onChange(of: undoTick) { _ in undoLastSwipe() }
        // Load cafes when view appears
        .task {
            vm.fetchCafes()
            didLoad = true
        }
    }

    // MARK: - Undo last swipe
    private func undoLastSwipe() {
        guard let last = history.popLast() else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            vm.cafes.insert(last, at: 0)
            topProgress = 0
        }
    }
}
