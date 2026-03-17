import SwiftUI

/// A circular avatar view for the profile user profile whoto
/// Supports tapping the edit button to trigger edit action to change username and photo.
struct AvatarWithEditButton: View {
    var size: CGFloat = 84
    var imageURL: URL? = nil
    var onEdit: () -> Void
    @Environment(\.colorScheme) private var scheme
    private var labelColor: Color { scheme == .dark ? .black : .white }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                // Get the imageUrl for the profile picture
                if let url = imageURL {
                    if #available(iOS 15.0, *) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(AppColor.circleTwo.opacity(0.2))
                                    .overlay(ProgressView())
                            case .success(let image):
                                image // Update the profile picture
                                    .resizable()
                                    .scaledToFill()
                            // Use place holder image if there is no profile picture
                            case .failure:
                                placeholder
                            @unknown default:
                                placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(.black.opacity(0.06), lineWidth: 1))
            // Edit button to change the profile photo. On click prompts user to edi username or profile pic
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppColor.primary)
                    .foregroundStyle(labelColor)
                    .clipShape(Capsule())
                    .shadow(radius: 1, y: 1)
            }
            .accessibilityLabel("Edit profile")
            .offset(x: 6, y: 6)
        }
    }
    
    // MARK: - Placeholder for missing image
    private var placeholder: some View {
        Circle()
            .fill(AppColor.circleTwo.opacity(0.2))
            .overlay(
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColor.primary.opacity(0.85))
                    .padding(size * 0.16)
            )
    }
}
