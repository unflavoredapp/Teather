import Foundation
import Security
import ZIPFoundation

// MARK: - Library

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var items: [IPAItem] = []
    @Published var busyID: UUID?
    @Published var log: [String] = []
    @Published var errorMessage: String?

    let root: URL
    private var indexURL: URL { root.appendingPathComponent("index.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = base.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        load()
    }

    func url(for item: IPAItem) -> URL { root.appendingPathComponent(item.fileName) }
    func signedURL(for item: IPAItem) -> URL { root.appendingPathComponent(item.signedFileName) }

    // MARK: Import

    func importIPA(from source: URL) throws {
        guard source.pathExtension.lowercased() == "ipa" else { throw LibraryError.notAnIPA }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let id = UUID()
        let dest = root.appendingPathComponent("\(id.uuidString).ipa")
        try FileManager.default.copyItem(at: source, to: dest)

        do {
            let meta = try Self.readMetadata(ipa: dest)
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            items.insert(
                IPAItem(id: id, displayName: meta.name, bundleID: meta.bundleID,
                        version: meta.version, addedAt: Date(), state: .unsigned, sizeBytes: size),
                at: 0
            )
            save()
        } catch {
            try? FileManager.default.removeItem(at: dest)
            throw error
        }
    }

    static func readMetadata(ipa: URL) throws -> (name: String, bundleID: String, version: String) {
        let archive = try Archive(url: ipa, accessMode: .read)
        let pattern = #"^Payload/[^/]+\.app/Info\.plist$"#
        guard let entry = archive.first(where: { $0.path.range(of: pattern, options: .regularExpression) != nil }) else {
            throw LibraryError.noInfoPlist
        }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw LibraryError.badInfoPlist
        }
        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? bundleID
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "?"
        return (name, bundleID, version)
    }

    // MARK: Sign & install

    func signAndInstall(_ item: IPAItem, method: SigningMethod, services: Services) async {
        guard busyID == nil else { return }
        busyID = item.id
        log = []
        errorMessage = nil
        defer { busyID = nil }

        let append: (String) -> Void = { [weak self] line in
            Task { @MainActor in self?.log.append(line) }
        }

        do {
            append("Signing \(item.displayName) with \(method.rawValue)…")
            try await services.signer.sign(ipa: url(for: item), to: signedURL(for: item), method: method, log: append)
            update(item.id) { $0.state = .signed }

            append("Installing…")
            try await services.installer.install(ipa: signedURL(for: item), log: append)
            update(item.id) { $0.state = .installed }
            if UserDefaults.standard.object(forKey: "keepSignedCopies") as? Bool == false {
                try? FileManager.default.removeItem(at: signedURL(for: item))
            }
            append("Done.")
        } catch {
            errorMessage = error.localizedDescription
            append("Failed: \(error.localizedDescription)")
        }
    }

    /// Installs the IPA exactly as imported, for apps that are already signed with a
    /// certificate this device trusts. Nothing is re-signed.
    func installAsIs(_ item: IPAItem, services: Services) async {
        guard busyID == nil else { return }
        busyID = item.id
        log = []
        errorMessage = nil
        defer { busyID = nil }

        let append: (String) -> Void = { [weak self] line in
            Task { @MainActor in self?.log.append(line) }
        }
        do {
            append("Installing \(item.displayName) as-is…")
            try await services.installer.install(ipa: url(for: item), log: append)
            update(item.id) { $0.state = .installed }
            append("Done.")
        } catch {
            errorMessage = error.localizedDescription
            append("Failed: \(error.localizedDescription)")
        }
    }

    func delete(_ item: IPAItem) {
        try? FileManager.default.removeItem(at: url(for: item))
        try? FileManager.default.removeItem(at: signedURL(for: item))
        items.removeAll { $0.id == item.id }
        save()
    }

    private func update(_ id: UUID, _ change: (inout IPAItem) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([IPAItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}

// MARK: - Pairing

@MainActor
final class PairingStore: ObservableObject {
    @Published private(set) var fileName: String?
    @Published var errorMessage: String?

    private let dir: URL
    private var target: URL { Self.importedFileURL }

    /// Where an imported (Manual mode) pairing file is kept. The native layer reads it from here.
    static var importedFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pairing", isDirectory: true)
            .appendingPathComponent("pairing.plist")
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Pairing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileName = UserDefaults.standard.string(forKey: "pairingFileName")
        if !FileManager.default.fileExists(atPath: target.path) { fileName = nil }
    }

    var isPaired: Bool { fileName != nil }
    var pairingFileURL: URL { target }

    func importFile(from source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: source)
            // Pairing records are property lists; reject anything else early.
            guard (try? PropertyListSerialization.propertyList(from: data, format: nil)) is [String: Any] else {
                throw ServiceError.failed("That doesn't look like a pairing file (expected a property list).")
            }
            try data.write(to: target, options: .atomic)
            fileName = source.lastPathComponent
            UserDefaults.standard.set(fileName, forKey: "pairingFileName")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: target)
        UserDefaults.standard.removeObject(forKey: "pairingFileName")
        fileName = nil
    }
}

// MARK: - Custom certificate

@MainActor
final class CertificateStore: ObservableObject {
    @Published private(set) var certificateName: String?
    @Published private(set) var profileName: String?
    @Published private(set) var profileExpiry: Date?
    @Published var errorMessage: String?

    private let dir: URL
    private var p12URL: URL { dir.appendingPathComponent("signing.p12") }
    private var profileURL: URL { dir.appendingPathComponent("signing.mobileprovision") }
    private let keychainService = "com.example.sideloader.p12"

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Certificates", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        certificateName = UserDefaults.standard.string(forKey: "certName")
        if let data = try? Data(contentsOf: profileURL) {
            let info = Self.profileInfo(data)
            profileName = info.name
            profileExpiry = info.expiry
        }
    }

    var isReady: Bool { certificateName != nil && profileName != nil }

    func importP12(from source: URL, password: String) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: source)
            var items: CFArray?
            let status = SecPKCS12Import(
                data as CFData,
                [kSecImportExportPassphrase as String: password] as CFDictionary,
                &items
            )
            guard status == errSecSuccess,
                  let first = (items as? [[String: Any]])?.first,
                  let identityRef = first[kSecImportItemIdentity as String] else {
                throw ServiceError.failed("Couldn't open that .p12. Check the password.")
            }
            var cert: SecCertificate?
            SecIdentityCopyCertificate(identityRef as! SecIdentity, &cert)
            let name = cert.flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "Certificate"

            try data.write(to: p12URL, options: .atomic)
            try storePassword(password)
            certificateName = name
            UserDefaults.standard.set(name, forKey: "certName")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importProfile(from source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: source)
            let info = Self.profileInfo(data)
            guard info.name != nil else {
                throw ServiceError.failed("That doesn't look like a .mobileprovision file.")
            }
            try data.write(to: profileURL, options: .atomic)
            profileName = info.name
            profileExpiry = info.expiry
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: p12URL)
        try? FileManager.default.removeItem(at: profileURL)
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService] as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "certName")
        certificateName = nil
        profileName = nil
        profileExpiry = nil
    }

    func loadPassword() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Helpers

    private func storePassword(_ password: String) throws {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService] as CFDictionary)
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecValueData: Data(password.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw ServiceError.failed("Couldn't save the password to Keychain.") }
    }

    /// A .mobileprovision is a CMS blob wrapping an XML plist; pull the plist out.
    static func profileInfo(_ data: Data) -> (name: String?, expiry: Date?) {
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any]
        else { return (nil, nil) }
        return (plist["Name"] as? String, plist["ExpirationDate"] as? Date)
    }
}

// MARK: - Apple ID

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var email: String?
    @Published var isBusy = false
    @Published var needsCode = false
    @Published var errorMessage: String?

    private var codeContinuation: CheckedContinuation<String?, Never>?

    init() { email = UserDefaults.standard.string(forKey: "appleIDEmail") }

    var isSignedIn: Bool { email != nil }

    func signIn(email: String, password: String, service: AppleAccountService) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false; needsCode = false }
        do {
            try await service.signIn(email: email, password: password) { [weak self] in
                await self?.awaitCode()
            }
            self.email = email
            UserDefaults.standard.set(email, forKey: "appleIDEmail")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut(service: AppleAccountService) async {
        await service.signOut()
        email = nil
        UserDefaults.standard.removeObject(forKey: "appleIDEmail")
    }

    func submitCode(_ code: String?) {
        codeContinuation?.resume(returning: code)
        codeContinuation = nil
        needsCode = false
    }

    private func awaitCode() async -> String? {
        needsCode = true
        return await withCheckedContinuation { codeContinuation = $0 }
    }
}
