import SwiftUI

/// A small vertical stat view for user profiles, showing a number and a label (e.g., "12 Memories")
struct ProfileStat: View {
    let number: Int       // The main numeric value to display
    let label: String     // A short label describing the stat

    var body: some View {
        VStack(spacing: 2) {
            // Display the number with emphasis
            Text("\(number)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.primary)

            // Display the label below the number
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number) \(label)") // Combine number + label for VoiceOver
    }
}
