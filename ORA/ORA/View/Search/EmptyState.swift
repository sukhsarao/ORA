import SwiftUI

/// A reusable empty-state view showing a title, subtitle, optional tips, and a primary action button.
/// Includes a small rotating sparkle animation for visual flair.
struct EmptyState: View {
    @State private var anim = false
    
    /// Main title of the empty state
    let title: String
    
    /// Subtitle providing additional context
    let subtitle: String
    
    /// Optional tips displayed as a checklist
    let tips: [String]
    
    /// Text for the primary button
    let primaryTitle: String
    
    /// Callback executed when the primary button is tapped
    var onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Animated sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(AppColor.primary)
                .rotationEffect(.degrees(anim ? 6 : -6))
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: anim)

            // Title and subtitle
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            // Tips checklist
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.primary.opacity(0.9))
                            .padding(.top, 2)
                        Text(tip)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)

            // Primary action button
            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                    Text(primaryTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.primary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppColor.primary.opacity(0.22), radius: 8, x: 0, y: 5)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .onAppear { anim = true } // Start sparkle animation
    }
}
