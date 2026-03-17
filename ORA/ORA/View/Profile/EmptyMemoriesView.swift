import SwiftUI

/// A view shown when the user has no memories uploaded yet.
/// Provides a prompt and button to add the first memory.
///
/// - Parameters:
///   - onAdd: Closure triggered when the user taps the "Add a memory" button.
struct EmptyMemoriesView: View {
    var onAdd: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            // Show default messages
            Text("No memories yet")
                .font(.headline)

            Text("Upload your first cafe memory to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Open the add memoery
            Button(action: onAdd) {
                Label("Add a memory", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(AppColor.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .accessibilityHint("Opens the add memory sheet")
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.circleOne.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
    }
}
