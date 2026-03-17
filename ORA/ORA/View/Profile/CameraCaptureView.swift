import SwiftUI
import UIKit

/// A SwiftUI wrapper around `UIImagePickerController` that allows capturing photos
/// using the device camera or picking images from the photo library if the camera is unavailable.
struct CameraCaptureView: UIViewControllerRepresentable {
    
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?   // Bound to the image picked or captured
    
    // MARK: - UIViewControllerRepresentable
    
    /// Creates and configures the UIImagePickerController
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        // Check if device has a camera
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Fallback to photo library if no camera
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = context.coordinator
            picker.modalPresentationStyle = .fullScreen
            return picker
        }

        // Configure camera mode
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen

        // Prefer rear camera
        if UIImagePickerController.isCameraDeviceAvailable(.rear) {
            picker.cameraDevice = .rear
        }

        // Set capture mode to photo only
        picker.cameraCaptureMode = .photo

        // Accept only images
        picker.mediaTypes = ["public.image"]

        return picker
    }

    /// Updates the picker (no dynamic updates needed here)
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Creates the coordinator that handles delegate callbacks
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    /// Coordinator to handle UIImagePickerController delegate methods
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        /// Called when an image is picked or captured
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer edited image if available
            let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.image = img
            UIImpactFeedbackGenerator(style: .light).impactOccurred() // haptic feedback
            picker.dismiss(animated: true) { self.parent.dismiss() }
        }

        /// Called when the user cancels the picker
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.parent.dismiss() }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Scales the image to fit within a maximum dimension while preserving aspect ratio,
    /// then converts it to JPEG data with the specified quality.
    /// - Parameters:
    ///   - maxDimension: Maximum width or height of the scaled image
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: JPEG data of the scaled image
    func jpeg(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        let scaleFactor = longest > maxDimension ? (maxDimension / longest) : 1
        let targetSize = CGSize(width: size.width * scaleFactor,
                                height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let scaled = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaled.jpegData(compressionQuality: quality)
    }
}
