import SwiftUI
import PhotosUI
import Photos

/// Protocol that defines a standard method to update a user's profile.
protocol ProfileUpdating {
    /// Updates the user's profile with a display name and optional avatar image data.
    /// - Parameters:
    ///   - displayName: The new display name.
    ///   - avatarData: Optional avatar image data in JPEG/PNG format.
    ///   - completion: Completion handler with an optional `Error`.
    func updateProfile(displayName: String, avatarData: Data?, completion: @escaping (Error?) -> Void)
}

/// A SwiftUI sheet that allows users to edit their profile.
/// Features:
/// - Update display name
/// - Pick or take a new profile photo using the photo library or camera
/// - Remove the new avatar
/// - Save changes to the backend via `ProfileUpdating` protocol
struct EditProfileSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @Environment(\.colorScheme) private var scheme

    // MARK: - State variables
    @State private var displayName: String = ""       // User's display name
    @State private var pickerItem: PhotosPickerItem? // Selected photo from photo library
    @State private var avatar: UIImage?              // Local image chosen by user
    @State private var remoteAvatarURL: URL?        // Existing avatar URL from backend
    @State private var isSaving = false             // Indicates save in progress
    @State private var errorMessage: String?        // Error message shown in form

    @State private var photoStatus: PHAuthorizationStatus = PermissionManager.photosStatus() // Photo permissions
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    // MARK: - Computed properties
    /// Returns the trimmed display name for validation.
    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    /// Returns true if either the display name or avatar has changes.
    private var hasChanges: Bool {
        let current = (auth.currentUser?.username ?? "")
        return trimmedName != current || avatar != nil
    }
    
    /// Color of the camera icon depending on light/dark mode.
    private var camIconColor: Color { scheme == .dark ? .black : .white }

    // MARK: - Body
    var body: some View {
        Form {
            // Avatar section
            Section {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let avatar {
                                Image(uiImage: avatar).resizable().scaledToFill()
                                // If there is a existing profile photo, fetch remote url
                            } else if let url = remoteAvatarURL {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { ProgressView() }
                            } else {
                                Image(systemName: "person.crop.circle.fill") // Use defualt pic if no profile picture
                                    .resizable().scaledToFit()
                                    .foregroundStyle(AppColor.primary.opacity(0.85))
                                    .padding(18)
                            }
                        }
                        .frame(width: 100, height: 100)
                        .background(AppColor.circleTwo.opacity(0.18))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.black.opacity(0.06), lineWidth: 1))

                        // Photo picker button
                        if photoStatus == .authorized || photoStatus == .limited {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Image(systemName: "camera.fill")
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppColor.primary)
                                    .foregroundStyle(camIconColor)
                                    .clipShape(Circle())
                                    .shadow(radius: 1, y: 1)
                                    .padding(4)
                            }
                            .onChange(of: pickerItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        avatar = img
                                    }
                                }
                            }
                        } else {
                            // Request permission button if not authorized
                            Button {
                                Task {
                                    let result = await PermissionManager.requestPhotos()
                                    photoStatus = PermissionManager.photosStatus()
                                    if case .denied = result {
                                        permissionMessage = "Photos access is disabled. Open Settings → Privacy → Photos to allow access."
                                        showPermissionAlert = true
                                    }
                                }
                            } label: {
                                Image(systemName: "camera.fill")
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppColor.primary)
                                    .foregroundStyle(camIconColor)
                                    .clipShape(Circle())
                                    .shadow(radius: 1, y: 1)
                                    .padding(4)
                            }
                            .accessibilityLabel("Allow Photos")
                        }
                    }

                    // Remove selected avatar button
                    if avatar != nil {
                        Button(role: .destructive) { avatar = nil } label: {
                            Label("Remove new photo", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Display name section
            Section("Display name") {
                TextField("Your name", text: $displayName) // Show user name
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.name)
                    .foregroundColor(.primary)
                    .tint(AppColor.primary)
            }

            // Error message
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)

        // Toolbar buttons
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() } // Cancel if no changes to be made
            }
            ToolbarItem(placement: .confirmationAction) {
                Button { save() } label: { // Save the updated profile
                    if isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                }
                .disabled(!hasChanges || trimmedName.isEmpty || isSaving)
            }
        }

        // Bottom save button
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Divider()
                Button(action: save) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView() } // Update state and show progress view when saving
                        Text("Save changes").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background((hasChanges && !trimmedName.isEmpty && !isSaving) // Check if anything has changed since edit sheet was opened
                                ? AppColor.primary
                                : AppColor.primary.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!hasChanges || trimmedName.isEmpty || isSaving) // Disable the button when saving.
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }

        // On appear, load current profile data
        .onAppear {
            displayName = auth.currentUser?.username ?? ""
            if let urlStr = auth.currentUser?.profilePhotoUrl,
               let url = URL(string: urlStr) {
                remoteAvatarURL = url
            }
            photoStatus = PermissionManager.photosStatus()
        }

        // Photo permission alert
        .alert("Permission Needed", isPresented: $showPermissionAlert) {
            Button("Open Settings", action: PermissionManager.openSettings)
            Button("OK", role: .cancel) {}
        } message: { Text(permissionMessage) }
    }

    // MARK: - Actions

    /// Saves the profile by sending the display name and avatar to the `AuthManager`
    private func save() {
        isSaving = true
        errorMessage = nil

        let data = avatar?.jpeg(maxDimension: 1024, quality: 0.85)

        auth.updateProfile(displayName: trimmedName, avatarData: data) { error in
            Task { @MainActor in
                isSaving = false
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            }
        }
    }
}
