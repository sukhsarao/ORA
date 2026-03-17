import SwiftUI

// MARK: - RadialCircle
/// A reusable circular view filled with a radial gradient.
///
/// Parameters:
/// - `size`: The diameter of the circle in points.
/// - `colors`: An array of colors used in the gradient, starting from the center to the edge.
struct RadialCircle: View {
    
    let size: CGFloat
    let colors: [Color]
    
    var body: some View {
        Circle()
            // Apply a radial gradient that fills the circle
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: colors), // Gradient colors
                    center: .center,                    // Center of the gradient
                    startRadius: 0,                     // Gradient starts at the center
                    endRadius: size                     // Gradient extends to the edge
                )
            )
            // Set the frame to make the circle the desired size
            .frame(width: size, height: size)
    }
}
