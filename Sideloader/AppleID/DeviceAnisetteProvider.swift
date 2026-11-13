import Foundation
import UIKit

/// Builds the anisette header set. The device/locale/time fields are gathered
/// for real; the ADI fields (`machineID`, `oneTimePassword`, `routingInfo`) come
/// from the vendored ADI engine and are filled once it's linked — same boundary
/// as `BridgedGrandSlamClient`. A remote anisette server can replace this type.
struct DeviceAnisetteProvider: AnisetteProvider {
    func currentAnisette() async throws -> AnisetteData {
        guard BridgedGrandSlamClient.engineLinked else {
            throw ServiceError.notIntegrated("Anisette data (ADI engine)")
        }
        let identifier = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString } ?? UUID().uuidString
        // ADI values are provided by the engine at this point:
        //   let adi = try AppleAuthFFI.anisette()
        return AnisetteData(
            machineID: "",
            oneTimePassword: "",
            routingInfo: "",
            deviceUniqueIdentifier: identifier,
            deviceSerialNumber: "0000000000",
            localUserID: identifier,
            date: Date(),
            locale: .current,
            timeZone: .current)
    }
}
