import Foundation

// MARK: - Apple ID authentication (GrandSlam)
//
// This is the ONE piece that cannot run or be tested in this build environment.
// Apple's GrandSlam (GSA) login is an SRP-6a handshake over 2048-bit math plus
// "anisette" data (a per-device one-time-password set Apple's servers expect).
// On iOS without a Mac, AltStore/SideStore satisfy anisette with a bundled ADI
// implementation. Re-implementing SRP + ADI correctly needs big-integer crypto
// and a real device, so that work lives behind `AppleAuthenticating` and is
// provided by a vendored engine (see `BridgedGrandSlamClient`). Everything the
// rest of this file and the Developer Services client do is real and talks to
// Apple's production endpoints once a session token comes back.

/// The authenticated session handed back by GrandSlam and consumed by
/// `AppleDeveloperServicesClient`.
struct AppleSession {
    /// Apple ID (DSID) of the signed-in account.
    var dsid: String
    /// GrandSlam application-specific token for Xcode / developer services.
    var authToken: String
    /// The account's email, for display.
    var email: String
    /// Anisette snapshot captured at login; developer-services calls replay it.
    var anisette: AnisetteData
}

/// The per-request anisette headers Apple expects on GrandSlam and
/// developer-services traffic.
struct AnisetteData {
    var machineID: String          // X-Apple-I-MD-M
    var oneTimePassword: String    // X-Apple-I-MD
    var routingInfo: String        // X-Apple-I-MD-RINFO
    var deviceUniqueIdentifier: String
    var deviceSerialNumber: String
    var localUserID: String
    var date: Date
    var locale: Locale
    var timeZone: TimeZone

    /// Header set replayed on every authenticated Apple request.
    var headers: [String: String] {
        let df = ISO8601DateFormatter()
        return [
            "X-Apple-I-MD": oneTimePassword,
            "X-Apple-I-MD-M": machineID,
            "X-Apple-I-MD-RINFO": routingInfo,
            "X-Apple-I-MD-LU": localUserID,
            "X-Apple-I-SRL-NO": deviceSerialNumber,
            "X-Mme-Device-Id": deviceUniqueIdentifier,
            "X-Apple-I-Client-Time": df.string(from: date),
            "X-Apple-Locale": locale.identifier,
            "X-Apple-I-TimeZone": timeZone.identifier
        ]
    }
}

/// Supplies anisette data. On device this is backed by the vendored ADI engine;
/// a remote anisette server can be dropped in by implementing this protocol.
protocol AnisetteProvider {
    func currentAnisette() async throws -> AnisetteData
}

/// GrandSlam login. `requestCode` is invoked when Apple requires a 2FA code.
protocol AppleAuthenticating {
    func authenticate(email: String,
                      password: String,
                      anisette: AnisetteProvider,
                      requestCode: @escaping () async -> String?) async throws -> AppleSession
}

// MARK: - Vendored engine seam

/// Binds to the vendored GrandSlam/ADI engine. The engine itself is added
/// through the same Rust-native build pipeline used for the device tunnel
/// (`Native/` → xcframework); this type is the Swift boundary to it.
///
/// Until the engine is linked, `authenticate` throws `ServiceError.notIntegrated`
/// so the UI degrades gracefully instead of crashing. The Custom Certificate
/// signing path works without any of this.
struct BridgedGrandSlamClient: AppleAuthenticating {
    /// Set true once the native auth engine is linked in `Native/`.
    static var engineLinked = false

    func authenticate(email: String,
                      password: String,
                      anisette: AnisetteProvider,
                      requestCode: @escaping () async -> String?) async throws -> AppleSession {
        guard Self.engineLinked else {
            throw ServiceError.notIntegrated("Apple ID sign-in (GrandSlam auth engine)")
        }
        // The native engine performs SRP-6a + 2FA + ADI and returns a session.
        // Bridging call lands here once `Native/AppleAuth` is built:
        //   return try await AppleAuthFFI.authenticate(email, password, anisette, requestCode)
        throw ServiceError.notIntegrated("Apple ID sign-in (GrandSlam auth engine)")
    }
}
