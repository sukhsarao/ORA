import SwiftUI

// MARK: - CoffeeLayout
/// A custom layout that arranges two background circular views and leaves space for
/// centered content (like logos or text).
/// - First circle is offset toward the top-right.
/// - Second circle is offset toward the bottom-left.
/// This layout is typically used for branding backgrounds on onboarding or welcome screens.
struct CoffeeLayout: Layout {
    
    /// Calculates the size that fits all subviews.
    /// - Parameters:
    ///   - proposal: The proposed size from the parent view.
    ///   - subviews: The child views (expected to have 2 circles).
    ///   - cache: Unused here, but required by protocol.
    /// - Returns: The total size needed to display the layout.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Measure subviews: circle1, circle2
        let circle1Size = subviews[0].sizeThatFits(.unspecified)
        let circle2Size = subviews[1].sizeThatFits(.unspecified)
        
        // Determine width (use proposed width or fit all content)
        let width = proposal.width ?? max(circle1Size.width, circle2Size.width)
        
        // Determine height to allow circles to be visible
        // Height is the height of the circles plus 20% extra for offsets + padding between them
        let height = (circle1Size.height * 1.2) + (circle2Size.height * 1.2) + 40
        
        return CGSize(width: width, height: height)
    }
    
    /// Places subviews inside the given bounds.
    /// - Parameters:
    ///   - bounds: The rectangle in which to place subviews.
    ///   - proposal: Proposed size from parent.
    ///   - subviews: The child views to position.
    ///   - cache: Unused here, required by protocol.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Retrieve measured sizes
        let circle1Size = subviews[0].sizeThatFits(.unspecified)
        let circle2Size = subviews[1].sizeThatFits(.unspecified)

        // Place the first circle (offset toward top-right)
        let circle1Center = CGPoint(
            x: bounds.maxX - circle1Size.width * 0.1,
            // 40% lower than top for a nice vertical offset
            y: bounds.minY + circle1Size.height * 0.4
        )
        subviews[0].place(
            at: circle1Center,
            anchor: .center,
            proposal: ProposedViewSize(width: circle1Size.width, height: circle1Size.height)
        )
        
        // Place the second circle (offset toward bottom-left)
        let circle2Center = CGPoint(
            x: bounds.minX + circle2Size.width * 0.2,
            y: bounds.maxY - circle2Size.height * 0.5
        )
        subviews[1].place(
            at: circle2Center,
            anchor: .center,
            proposal: ProposedViewSize(width: circle2Size.width, height: circle2Size.height)
        )
    }
}
