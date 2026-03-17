import SwiftUI

/// Reusable header bar used across ORA screens.
/// Displays the app title on the left and optional action buttons on the right.
/// Action buttons include Undo, Add Folder/Memory, and Settings.
/// Accessibility labels are provided for VoiceOver support.
struct ORAHeader: View {
    /// Closure invoked when Undo button is tapped.
    var onUndo: (() -> Void)? = nil

    /// Closure invoked when Add Folder button is tapped.
    var onAddFolder: (() -> Void)? = nil

    /// Closure invoked when Add Memory button is tapped.
    var onAddMemory: (() -> Void)? = nil

    /// Closure invoked when Settings button is tapped.
    var onSettings: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // App title
            Text("ORA")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(AppColor.primary)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            Spacer()

            // Undo button for undoing a swipe card action.
            if let onUndo {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColor.primary)
                        .accessibilityLabel("Undo last swipe")
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
            }

            // Add Memory / Add Folder button
            if let addAction = (onAddMemory ?? onAddFolder) {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColor.primary)
                        .accessibilityLabel("Add memory")
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
            }

            // Settings button
            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColor.primary)
                        .accessibilityLabel("Settings")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
