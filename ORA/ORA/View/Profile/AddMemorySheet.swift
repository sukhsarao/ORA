import SwiftUI
import PhotosUI
import Photos
import FirebaseAuth
import FirebaseFirestore

/// A sheet that allows users to add a new memory with a photo, caption, and optional cafe tag.
/// Handles picking from the photo library, taking a photo with the camera, and posting to the backend.
/// Also supports public/private toggling, cafe selection, and error handling.
struct AddMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memories: MemoryStore

    @State private var pickerItem: PhotosPickerItem? // Allows to choose photo
    @State private var selectedImage: UIImage? // Selected image
    @State private var caption = ""
    @State private var cafeTag = ""
    
    @StateObject private var cafeVM = CafeViewModel()
    // If it is public then share recent photo with the cafe otherwise keep it on users profile
    @State private var isPublic = true
    @State private var selectedCafe: Cafe?
    @State private var searchText = ""

    // Camera
    @State private var showCamera = false
    private var canUseCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    // Permissions UI
    @State private var photoStatus: PHAuthorizationStatus = PermissionManager.photosStatus()
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""

    // Posting state
    @State private var isPosting = false
    @State private var postError: String?
    @State private var showPostError = false

    private var trimmedCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isPostEnabled: Bool { selectedImage != nil && !trimmedCaption.isEmpty && !isPosting }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppColor.circleOne.opacity(0.22))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.black.opacity(0.08), lineWidth: 1))

                    VStack(spacing: 12) {
                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .frame(height: 260)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal, 12)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .regular))
                                .foregroundColor(AppColor.primary.opacity(0.7))
                                .padding(.top, 32)
                        }
                        // Photo picker
                        HStack(spacing: 12) {
                            if photoStatus == .authorized || photoStatus == .limited {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Label("Choose Photo", systemImage: "photo")
                                        .font(.headline)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(AppColor.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .onChange(of: pickerItem) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                                           let img = UIImage(data: data) {
                                            selectedImage = img
                                        }
                                    }
                                }
                            } else {
                                Button {
                                    Task {
                                        // Permissions handler
                                        let result = await PermissionManager.requestPhotos()
                                        photoStatus = PermissionManager.photosStatus() // Give permission to take photos
                                        if case .denied = result {
                                            permissionMessage = "Photos access is disabled. Open Settings → Privacy → Photos to allow access."
                                            showPermissionAlert = true
                                        }
                                    }
                                } label: {
                                    Label("Allow Photos", systemImage: "photo.on.rectangle") 
                                        .font(.headline)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(AppColor.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            Button {
                                // For debugging and error handling
                                guard canUseCamera else {
                                    permissionMessage = "Camera is not available on this device (Simulator)."
                                    showPermissionAlert = true
                                    return
                                }
                                // Handles permissions for the camera to take a photo for the memory
                                switch PermissionManager.cameraStatus() {
                                case .authorized:
                                    showCamera = true
                                case .notDetermined:
                                    Task {
                                        let result = await PermissionManager.requestCamera()
                                        if result == .granted { showCamera = true }
                                        else {
                                            permissionMessage = "Please allow camera access in Settings to take photos."
                                            showPermissionAlert = true
                                        }
                                    }
                                case .denied, .restricted:
                                    permissionMessage = "Camera access is disabled. Open Settings → Privacy → Camera to allow access."
                                    showPermissionAlert = true
                                @unknown default:
                                    permissionMessage = "Camera permission is unavailable."
                                    showPermissionAlert = true
                                }
                            // Take a photo for a memory
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background((canUseCamera ? AppColor.primary : .gray).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .disabled(!canUseCamera)
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                
                // Memoeries details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Caption")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    // Place holder for caption
                    TextField("OMG my fav cafe", text: $caption)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .foregroundColor(.primary)
                        .tint(AppColor.primary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.black.opacity(0.08), lineWidth: 1))
                    // A list of avaliable cafes so user can tag the cafe
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add a cafe")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        // Make it searchable so it prompts avaliable cafes
                        TextField("Search cafes...", text: $searchText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                        
                        
                        if !searchText.isEmpty {
                            ScrollView {
                                ForEach(cafeVM.cafes.filter { $0.name.lowercased().contains(searchText.lowercased()) }) { cafe in
                                    Button {
                                        selectedCafe = cafe
                                        searchText = cafe.name // show selected
                                    } label: {
                                        Text(cafe.name)
                                            .padding(.horizontal)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                        // Toggle to switch on/off on whether new memeory is public or private
                        Toggle(isOn: $isPublic) {
                            Label(isPublic ? "Public" : "Private", systemImage: isPublic ? "globe" : "lock.fill")
                        }
                        .tint(AppColor.primary)
                        .padding(.top, 6)

                    }

                }
                .padding(.horizontal, 24)
                // Async task to post the memoery.
                Button {
                    Task { await postMemory() }
                } label: {
                    HStack(spacing: 8) {
                        if isPosting { ProgressView() }
                        // State handler for when posting is avaliable. If post is being uploaded then should not be able to post again
                        Text(isPosting ? "Posting..." : "Post")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isPostEnabled ? AppColor.primary : AppColor.primary.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(!isPostEnabled)
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .navigationTitle("New Memory")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(image: $selectedImage).ignoresSafeArea() // Take photo using camera
        }
        .onAppear {
            photoStatus = PermissionManager.photosStatus() // Permission handler for camera
            if cafeVM.cafes.isEmpty {
                   cafeVM.fetchCafes() // Get cafes to tag to appear when searching
               }
        }
        // Permissions alerts and error handling
        .alert("Permission Needed", isPresented: $showPermissionAlert) {
            Button("Open Settings", action: PermissionManager.openSettings)
            Button("OK", role: .cancel) {}
        } message: { Text(permissionMessage) }
        .alert("Couldn't Post", isPresented: $showPostError) {
            Button("OK", role: .cancel) {}
        } message: { Text(postError ?? "Unknown error") }
    }
    
    // Helper function to clean the cafe's name
    private var cleanedCafeName: String {
        if let selectedCafe { return selectedCafe.name }
        let t = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return t.first == "@" ? String(t.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) : t
    }
    

    /// Posts memory to backend using the `Memory Service`
    private func postMemory() async {
        guard let img = selectedImage else { return }
        isPosting = true
        postError = nil
        do {
            // Posts photo using memory service
            _ = try await MemoryService.shared.createMemory(
                image: img,
                caption: trimmedCaption,
                cafeTag: cleanedCafeName,
                selectedCafe: selectedCafe,
                isPublic: isPublic, // Check if the post is public or not if it is then share with the cafe's recents
                cafeId: selectedCafe?.id
            )
            // Once posted change the state
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isPosting = false
                dismiss()
            }
        } catch {
            // Catch any errors during the post
            await MainActor.run {
                isPosting = false
                postError = (error as NSError).localizedDescription
                showPostError = true
            }
        }
    }
}
