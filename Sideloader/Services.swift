import Foundation

// MARK: - Service seams
// These three protocols are where the native pieces plug in. The UI and the
// stores only talk to these, so swapping a stub for a real implementation
// doesn't touch any view code.

protocol IPASigner {
    /// Re-signs `ipa` and writes the result to `output`.
    func sign(ipa: URL, to output: URL, method: SigningMethod, log: @escaping (String) -> Void) async throws
}

protocol DeviceInstaller {
    /// Verifies the pairing file / loopback tunnel to this device works.
    func checkConnection() async throws
    /// Installs a signed IPA on this device.
    func install(ipa: URL, log: @escaping (String) -> Void) async throws
}

protocol AppleAccountService {
    /// `requestCode` is called if Apple asks for a two-factor code.
    func signIn(email: String, password: String, requestCode: @escaping () async -> String?) async throws
    func signOut() async
}

// MARK: - Stubs (replace with real implementations)

struct StubSigner: IPASigner {
    func sign(ipa: URL, to output: URL, method: SigningMethod, log: @escaping (String) -> Void) async throws {
        throw ServiceError.notIntegrated("IPA signing")
    }
}

struct StubInstaller: DeviceInstaller {
    func checkConnection() async throws {
        throw ServiceError.notIntegrated("The device tunnel")
    }
    func install(ipa: URL, log: @escaping (String) -> Void) async throws {
        throw ServiceError.notIntegrated("On-device install")
    }
}

struct StubAccountService: AppleAccountService {
    func signIn(email: String, password: String, requestCode: @escaping () async -> String?) async throws {
        throw ServiceError.notIntegrated("Apple ID sign-in")
    }
    func signOut() async {}
}

/// Holds the active service implementations. The installer is real (local tunnel +
/// pairing + installation_proxy). Signing is real via zsign: Custom Certificate works
/// today; the Apple ID path works once the GrandSlam auth engine is linked
/// (see `AppleAuth.swift`). The signer and account share one `AppleIDAccountService`
/// so a sign-in is visible to the signer.
struct Services {
    let appleAccount: AppleIDAccountService
    var signer: IPASigner
    var installer: DeviceInstaller = NativeDeviceInstaller()
    var account: AppleAccountService { appleAccount }

    @MainActor init() {
        let account = AppleIDAccountService()
        appleAccount = account
        signer = AppleIDSigner(account: account)
    }
}
