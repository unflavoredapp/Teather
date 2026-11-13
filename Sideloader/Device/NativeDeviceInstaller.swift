import Foundation
import Combine
import IDeviceSwift

/// `DeviceInstaller` backed by the native device layer: local tunnel + pairing +
/// installation_proxy. The IPA must already be signed with a certificate this device trusts.
struct NativeDeviceInstaller: DeviceInstaller {
    func checkConnection() async throws {
        try await DeviceConnection.shared.withDevice { }
    }

    func install(ipa: URL, log: @escaping (String) -> Void) async throws {
        try await DeviceConnection.shared.withDevice {
            log("Connected to this device.")
            let viewModel = InstallerStatusViewModel(isIdevice: true)
            var lastPercent = -1
            let observer = viewModel.objectWillChange.sink { _ in
                DispatchQueue.main.async {
                    let percent = Int(viewModel.overallProgress * 100)
                    if percent != lastPercent {
                        lastPercent = percent
                        log("Installing… \(percent)%")
                    }
                }
            }
            defer { observer.cancel() }
            try await InstallationProxy(viewModel: viewModel).install(at: ipa)
            log("Installed.")
        }
    }
}
