import Foundation

struct APIError: Codable { let error: String }
struct HealthResponse: Codable {
    let name: String
    let version: String
    let platform: String
    let capabilities: [String]
}
struct DeviceInfo: Codable, Identifiable {
    var id: String { udid }
    let udid: String
    let name: String?
    let productType: String?
    let productVersion: String?
    let buildVersion: String?
    let modelNumber: String?
    let connection: String
    let paired: Bool?
}
struct AppMetadata: Codable {
    let appID: String
    let bundleID: String
    let name: String
    let version: String?
    let minimumOSVersion: String?
    let seller: String?
    let artworkURL: String?
    let trackViewURL: String?
    let storefront: String
}
struct IPAInspection: Codable {
    let file: String
    let sizeBytes: Int64
    let sha256: String
    let appName: String
    let bundleID: String
    let shortVersion: String?
    let buildVersion: String?
    let minimumOSVersion: String?
    let executable: String?
    let appDirectory: String
    let containsWatchApp: Bool
}
struct DoctorCheck: Codable { let name: String; let available: Bool; let detail: String }
struct DoctorResponse: Codable { let checks: [DoctorCheck] }
