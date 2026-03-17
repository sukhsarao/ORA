import Foundation
import FirebaseAuth

/// Metadata returned from the backend for uploading a file to S3.
struct S3UploadInfo: Decodable {
    /// The presigned URL to PUT the file to S3.
    let uploadUrl: String
    
    /// The public URL to access the uploaded file.
    let fileUrl: String
    
    /// The S3 object key for the uploaded file.
    let key: String
    
    /// The Media type of the file.
    let contentType: String
}

/// Utilities for requesting presigned S3 URLs and deleting S3 objects.
enum S3Presign {
    /// The backend API endpoint for presign and delete operations.
    static let endpoint = URL(string: "https://zuh8rbq764.execute-api.ap-southeast-2.amazonaws.com/prod/presign")!

    private struct PresignBody: Encodable {
        let uid: String
        let contentType: String
        let folder: String
    }
    // Request body to delete image
    private struct DeleteBody: Encodable {
        let op: String = "delete"
        let uid: String
        let key: String
    }

    // MARK: - Auth

    /// Adds the Firebase ID token to the request if available.
    private static func attachAuthHeader(_ req: inout URLRequest) async {
        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Creates a JSON POST request with the appropriate headers and body.
    private static func makeJSONPostRequest<T: Encodable>(to url: URL, body: T) async throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        await attachAuthHeader(&req)
        return req
    }

    // MARK: - S3 Operations

    /// Requests a presigned URL and metadata for uploading a file to S3.
    /// - Parameters:
    ///   - contentType: The media type of the file.
    ///   - uid: The user ID.
    ///   - folder: The S3 folder path.
    /// - Returns: An `S3UploadInfo` containing upload and public URLs.
    /// - Throws: Network or decoding errors.
    static func requestUploadURL(contentType: String, uid: String, folder: String) async throws -> S3UploadInfo {
        let body = PresignBody(uid: uid, contentType: contentType, folder: folder)
        let req  = try await makeJSONPostRequest(to: endpoint, body: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(S3UploadInfo.self, from: data)
    }

    /// Uploads raw data to S3 using a presigned PUT URL.
    /// - Parameters:
    ///   - uploadUrl: The presigned PUT URL.
    ///   - data: The file data to upload.
    ///   - contentType: The media type of the file.
    /// - Throws: Network errors or unsuccessful status codes.
    static func putToS3(uploadUrl: URL, data: Data, contentType: String) async throws {
        var req = URLRequest(url: uploadUrl)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.cannotWriteToFile)
        }
    }

    /// Deletes an object from S3 via the backend API.
    /// - Parameters:
    ///   - key: The S3 object key.
    ///   - uid: The user ID.
    /// - Throws: Network errors or unsuccessful status codes.
    static func deleteObject(key: String, uid: String) async throws {
        let body = DeleteBody(uid: uid, key: key)
        let req  = try await makeJSONPostRequest(to: endpoint, body: body)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.cannotRemoveFile)
        }
    }
}
