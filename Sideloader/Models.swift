import Foundation

enum SigningMethod: String, CaseIterable, Identifiable {
    case appleID = "Apple ID"
    case customCertificate = "Custom Certificate"
    var id: String { rawValue }
}

struct IPAItem: Identifiable, Codable, Hashable {
    enum State: String, Codable { case unsigned, signed, installed }

    var id: UUID
    var displayName: String
    var bundleID: String
    var version: String
    var addedAt: Date
    var state: State
    var sizeBytes: Int64

    var fileName: String { "\(id.uuidString).ipa" }
    var signedFileName: String { "\(id.uuidString)-signed.ipa" }
}

enum LibraryError: LocalizedError {
    case noInfoPlist
    case badInfoPlist
    case notAnIPA

    var errorDescription: String? {
        switch self {
        case .noInfoPlist: return "No Payload/*.app/Info.plist found. Is this a valid .ipa?"
        case .badInfoPlist: return "The app's Info.plist could not be read."
        case .notAnIPA: return "That file isn't an .ipa archive."
        }
    }
}

enum ServiceError: LocalizedError {
    case notIntegrated(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notIntegrated(let what):
            return "\(what) isn't wired up yet. See README.md → \"Plugging in the native pieces\"."
        case .failed(let message):
            return message
        }
    }
}
