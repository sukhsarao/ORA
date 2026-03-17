import SwiftUI

/// A reusable error view displaying a title, message, and two action buttons.
/// Suitable for presenting recoverable errors with primary and secondary actions.
struct ErrorView: View {
    /// Error title displayed prominently
    var title: String
    
    /// Detailed message explaining the error
    var message: String
    
    /// Primary action: tuple of button title and action closure
    var primary: (String, () -> Void)
    
    /// Secondary action: tuple of button title and action closure
    var secondary: (String, () -> Void)

    var body: some View {
        VStack(spacing: 14) {
            // Error message container
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)

            // Action buttons: secondary (left), primary (right)
            HStack(spacing: 10) {
                Button(secondary.0, action: secondary.1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())

                Button(primary.0, action: primary.1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColor.primary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
}
