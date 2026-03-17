import AVFoundation
import Photos
import SwiftUI

/// Represents the result of a permission request
enum PermissionResult {
    case granted   // Full access granted
    case denied    // Access denied
    case limited   // Limited access (Photos only)
}

/// Utility for checking and requesting camera and photo library permissions
enum PermissionManager {

    // MARK: - Camera Permissions

    /// Returns the current camera authorization status
    static func cameraStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Requests access to the camera asynchronously
    /// - Returns: `.granted` if access allowed, `.denied` otherwise
    static func requestCamera() async -> PermissionResult {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                cont.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    // MARK: - Photo Library Permissions

    /// Returns the current photo library authorization status
    static func photosStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests access to the photo library asynchronously
    /// - Returns: `.granted`, `.limited`, or `.denied` depending on user choice
    static func requestPhotos() async -> PermissionResult {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .authorized: cont.resume(returning: .granted)
                case .limited:    cont.resume(returning: .limited)
                default:          cont.resume(returning: .denied)
                }
            }
        }
    }

    // MARK: - Open App Settings
    /// Opens the app's settings page so the user can manually update permissions
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
