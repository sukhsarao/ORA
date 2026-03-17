import SwiftUI

/// A full-screen backdrop view for ORA, adapting to light/dark mode.
struct ORABackdrop: View {
    @Environment(\.colorScheme) private var scheme
    // Simple backdrop view based on environment's color scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [AppColor.dark.opacity(1.0), AppColor.dark.opacity(0.94)]
                : [AppColor.circleOne.opacity(0.22), AppColor.circleTwo.opacity(0.14), Color(.systemBackground)],
            startPoint: scheme == .dark ? .top : .topLeading,
            endPoint: scheme == .dark ? .bottom : .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// Returns the fill style for chips, based on the color scheme.
/// - Parameter scheme: Current color scheme.
/// - Returns: A shape style for the chip background.
func chipFill(_ scheme: ColorScheme) -> some ShapeStyle {
    scheme == .dark ? Color.white.opacity(0.06)
                    : AppColor.circleTwo.opacity(0.18)
}

/// Returns the line color for separators or strokes.
/// - Parameter scheme: Current color scheme.
/// - Returns: Color for lines.
func line(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.12)
                    : AppColor.primary.opacity(0.07)
}

/// Returns the card background fill style, adapting to light/dark mode.
/// - Parameter scheme: Current color scheme.
/// - Returns: A shape style for card backgrounds.
func cardFill(_ scheme: ColorScheme) -> some ShapeStyle {
    if scheme == .dark {
        LinearGradient(colors: [AppColor.circleOne, AppColor.circleTwo],
                       startPoint: .top, endPoint: .bottom)
    } else {
        LinearGradient(colors: [AppColor.circleOne.opacity(0.26),
                                AppColor.circleTwo.opacity(0.18)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Returns a subtle shadow color for elements.
/// - Parameter scheme: Current color scheme.
/// - Returns: Color to use for shadows.
func subtleShadow(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.black.opacity(0.45)
                    : Color.black.opacity(0.08)
}
