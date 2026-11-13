import Foundation
import ZIPFoundation

// MARK: - Apple ID account service (free-account signing)
//
// Orchestrates the real flow AltStore uses for a free Apple ID:
//   authenticate (GrandSlam)  →  pick team  →  ensure a development certificate
//   (generate CSR locally, submit, receive cert, build a .p12)
// then, at sign time, register the app's bundle ID, download its provisioning
// profile, and hand both to zsign. The only piece that can't run in this build
// is the GrandSlam auth engine (see AppleAuth.swift); everything downstream is real.

@MainActor
final class AppleIDAccountService: AppleAccountService, ObservableObject {
    // Live account state, surfaced to the Developer Account screen.
    @Published private(set) var team: DeveloperTeam?
    @Published private(set) var certificates: [SigningCertificate] = []
    @Published private(set) var appIDs: [AppID] = []
    @Published private(set) var devices: [RegisteredDevice] = []

    private let authenticator: AppleAuthenticating
    private let anisette: AnisetteProvider
    /// Supplies this iPhone's UDID. The device layer already has it from the
    /// pairing/lockdown connection; inject that here.
    private let deviceUDID: () -> String?

    private var session: AppleSession?
    private var client: AppleDeveloperServicesClient?

    /// Where the Apple-ID-minted identity is written so zsign (and the Custom
    /// Certificate UI) can consume it.
    private let dir: URL
    private var p12URL: URL { dir.appendingPathComponent("appleid.p12") }
    let p12Password = "tetherless"   // local-only; the .p12 never leaves the device

    init(authenticator: AppleAuthenticating = BridgedGrandSlamClient(),
         anisette: AnisetteProvider = DeviceAnisetteProvider(),
         deviceUDID: @escaping () -> String? = { (try? DevicePairingStore.load())?.device_udid }) {
        self.authenticator = authenticator
        self.anisette = anisette
        self.deviceUDID = deviceUDID
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("AppleID", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: AppleAccountService

    func signIn(email: String, password: String, requestCode: @escaping () async -> String?) async throws {
        let session = try await authenticator.authenticate(email: email, password: password,
                                                           anisette: anisette, requestCode: requestCode)
        self.session = session
        let client = AppleDeveloperServicesClient(session: session)
        self.client = client

        // Pick the account's (only, for a free account) team.
        guard let team = try await client.teams().first else {
            throw ServiceError.failed("No development team on this Apple ID.")
        }
        self.team = team

        try await ensureCertificate(client: client, team: team, email: email)
        try await refresh()
    }

    func signOut() async {
        session = nil
        client = nil
        team = nil
        certificates = []; appIDs = []; devices = []
        try? FileManager.default.removeItem(at: p12URL)
    }

    /// Re-pulls the live lists for the Developer Account screen.
    func refresh() async throws {
        guard let client, let team else { return }
        async let c = client.certificates(teamID: team.id)
        async let a = client.appIDs(teamID: team.id)
        async let d = client.devices(teamID: team.id)
        certificates = try await c
        appIDs = try await a
        devices = try await d
    }

    func revoke(certificate: SigningCertificate) async throws {
        guard let client, let team else { return }
        try await client.revokeCertificate(id: certificate.serialNumber, teamID: team.id)
        try await refresh()
    }

    // MARK: Certificate + profile material (consumed by the signer)

    private func ensureCertificate(client: AppleDeveloperServicesClient, team: DeveloperTeam, email: String) async throws {
        // Generate a keypair + CSR locally, submit it, store the resulting .p12.
        var keyPEM: String?
        guard let csr = AppleIDCrypto.generateCSR(withCommonName: team.name, email: email, privateKeyPEM: &keyPEM),
              let keyPEM else {
            throw ServiceError.failed("Couldn't generate a signing request.")
        }
        let cert = try await client.submitCertificate(csr: Data(csr.utf8), teamID: team.id, machineName: "Tetherless")
        guard let der = cert.data else {
            throw ServiceError.failed("Apple didn't return certificate data.")
        }
        guard let p12 = AppleIDCrypto.pkcs12(withPrivateKeyPEM: keyPEM, certificateDER: der, password: p12Password) else {
            throw ServiceError.failed("Couldn't assemble the signing identity.")
        }
        try p12.write(to: p12URL, options: .atomic)
    }

    /// The .p12 + password for the current Apple-ID certificate, if signed in.
    func signingIdentity() -> (p12: URL, password: String)? {
        guard session != nil, FileManager.default.fileExists(atPath: p12URL.path) else { return nil }
        return (p12URL, p12Password)
    }

    /// Registers the bundle ID (if needed) and downloads its provisioning profile.
    func provisioningProfile(forBundleID bundleID: String, appName: String) async throws -> URL {
        guard let client, let team else { throw ServiceError.failed("Sign in with your Apple ID first.") }

        // Free accounts need a unique, team-scoped identifier per app.
        let identifier = "\(bundleID).\(team.id)"
        let existing = try await client.appIDs(teamID: team.id)
        if !existing.contains(where: { $0.identifier == identifier }) {
            _ = try await client.registerAppID(name: appName, bundleID: identifier, teamID: team.id)
        }

        // Make sure this device is registered, so the profile includes it.
        if let udid = deviceUDID() {
            let known = try await client.devices(teamID: team.id)
            if !known.contains(where: { $0.udid == udid }) {
                try await client.registerDevice(name: "Tetherless device", udid: udid, teamID: team.id)
            }
        }

        let data = try await client.provisioningProfile(appIDIdentifier: identifier, teamID: team.id)
        let url = dir.appendingPathComponent("\(UUID().uuidString).mobileprovision")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Apple ID signer (routes .appleID through zsign with minted material)

struct AppleIDSigner: IPASigner {
    /// Shared with `Services.account` so the signer sees the live session.
    let account: AppleIDAccountService
    /// Falls back to the Custom Certificate path for `.customCertificate`.
    let customCertificate = LocalZSignSigner()

    func sign(ipa: URL, to output: URL, method: SigningMethod, log: @escaping (String) -> Void) async throws {
        if method == .customCertificate {
            try await customCertificate.sign(ipa: ipa, to: output, method: method, log: log)
            return
        }

        guard let identity = await account.signingIdentity() else {
            throw ServiceError.failed("Sign in with your Apple ID in Settings first.")
        }
        let info = try Self.appInfo(ipa: ipa)
        log("Registering \(info.name)…")
        let profile = try await account.provisioningProfile(forBundleID: info.bundleID, appName: info.name)

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

            log("Signing with your Apple ID certificate…")
            let code = zsignWithOptions(app.path, profile.path, identity.p12.path, identity.password,
                                        "", "", "", nil, false, true)
            guard code == 0 else { throw ServiceError.failed("Signing failed.") }

            log("Repacking…")
            if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
            try fm.zipItem(at: payload, to: output, shouldKeepParent: true, compressionMethod: .deflate)
            log("Signed.")
        }.value
    }

    private static func appInfo(ipa: URL) throws -> (name: String, bundleID: String) {
        let archive = try Archive(url: ipa, accessMode: .read)
        for entry in archive where entry.path.hasSuffix(".app/Info.plist") && entry.path.hasPrefix("Payload/") {
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let bid = (plist["CFBundleIdentifier"] as? String) ?? "com.example.app"
                let name = (plist["CFBundleName"] as? String) ?? (plist["CFBundleDisplayName"] as? String) ?? "App"
                return (name, bid)
            }
        }
        throw ServiceError.failed("Couldn't read the app's Info.plist.")
    }
}
