import Foundation

struct IPAManager {
    func inspect(path: String) throws -> IPAInspection {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.pathExtension.lowercased() == "ipa", FileManager.default.fileExists(atPath: url.path) else {
            throw ProcessRunnerError.failed("Provide an existing .ipa file")
        }
        let listing = try ProcessRunner.requireSuccess("unzip", ["-Z1", url.path])
        let entries = listing.split(whereSeparator: \.isNewline).map(String.init)
        for entry in entries {
            let components = entry.split(separator: "/", omittingEmptySubsequences: false)
            if entry.hasPrefix("/") || components.contains("..") || entry.contains("\\") || entry.unicodeScalars.contains(where: { $0.value == 0 }) {
                throw ProcessRunnerError.failed("IPA contains an unsafe archive path")
            }
        }
        guard let infoPath = entries.first(where: { $0.range(of: #"^Payload/[^/]+\.app/Info\.plist$"#, options: .regularExpression) != nil }) else {
            throw ProcessRunnerError.failed("IPA does not contain Payload/<App>.app/Info.plist")
        }
        let plistResult = try ProcessRunner.run("unzip", ["-p", url.path, infoPath])
        guard plistResult.status == 0 else { throw ProcessRunnerError.failed("Unable to read app Info.plist from IPA") }
        let plistData = plistResult.stdoutBytes
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] ?? [:]
        guard let bundleID = plist["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            throw ProcessRunnerError.failed("Info.plist is missing CFBundleIdentifier")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let sha = try ProcessRunner.requireSuccess("sha256sum", [url.path]).split(separator: " ").first.map(String.init) ?? "unknown"
        return IPAInspection(file: url.lastPathComponent, sizeBytes: size, sha256: sha,
                             appName: (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent,
                             bundleID: bundleID, shortVersion: plist["CFBundleShortVersionString"] as? String,
                             buildVersion: plist["CFBundleVersion"] as? String,
                             minimumOSVersion: plist["MinimumOSVersion"] as? String,
                             executable: plist["CFBundleExecutable"] as? String,
                             appDirectory: URL(fileURLWithPath: infoPath).deletingLastPathComponent().path,
                             containsWatchApp: entries.contains(where: { $0.hasPrefix("Payload/") && $0.contains(".app/Watch/") }))
    }
    func extract(path: String, to destination: String) throws {
        _ = try inspect(path: path)
        let dest = URL(fileURLWithPath: destination).standardizedFileURL
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        _ = try ProcessRunner.requireSuccess("unzip", ["-oq", URL(fileURLWithPath: path).path, "-d", dest.path], timeout: 300)
    }
    func package(appDirectory: String, output: String) throws {
        let app = URL(fileURLWithPath: appDirectory).standardizedFileURL
        guard app.pathExtension == "app", FileManager.default.fileExists(atPath: app.appendingPathComponent("Info.plist").path) else {
            throw ProcessRunnerError.failed("Expected an extracted .app directory containing Info.plist")
        }
        let payload = app.deletingLastPathComponent()
        guard payload.lastPathComponent == "Payload" else { throw ProcessRunnerError.failed("App must be inside a Payload directory") }
        let parent = payload.deletingLastPathComponent()
        let out = URL(fileURLWithPath: output).standardizedFileURL
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: out.path) { try FileManager.default.removeItem(at: out) }
        _ = try ProcessRunner.requireSuccess("zip", ["-qr", out.path, "Payload"], timeout: 600, currentDirectory: parent.path)
    }
}
