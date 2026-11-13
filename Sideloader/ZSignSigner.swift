import Foundation
import ZIPFoundation

/// Re-signs an IPA on device with the bundled zsign engine, using the .p12 and
/// .mobileprovision imported under Settings → Custom Certificate.
struct LocalZSignSigner: IPASigner {
    func sign(ipa: URL, to output: URL, method: SigningMethod, log: @escaping (String) -> Void) async throws {
        guard method == .customCertificate else {
            throw ServiceError.failed("Apple ID signing isn't available yet. Choose Custom Certificate in Settings.")
        }
        guard let material = CertificateStore.signingMaterial() else {
            throw ServiceError.failed("Import a .p12 and a .mobileprovision in Settings first.")
        }
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("zsign-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: work) }

            log("Unpacking IPA…")
            try fm.unzipItem(at: ipa, to: work)
            let payload = work.appendingPathComponent("Payload", isDirectory: true)
            guard let appName = try fm.contentsOfDirectory(atPath: payload.path).first(where: { $0.hasSuffix(".app") }) else {
                throw ServiceError.failed("No .app found inside the IPA.")
            }
            let app = payload.appendingPathComponent(appName)

            log("Signing \(appName)…")
            let code = zsignWithOptions(app.path, material.profile.path, material.p12.path, material.password,
                                        "", "", "", nil, false, true)
            guard code == 0 else {
                throw ServiceError.failed("Signing failed. Check that the certificate, password and profile match.")
            }

            log("Repacking…")
            if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
            try fm.zipItem(at: payload, to: output, shouldKeepParent: true, compressionMethod: .deflate)
            log("Signed.")
        }.value
    }
}
