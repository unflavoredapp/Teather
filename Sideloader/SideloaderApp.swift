import SwiftUI

@main
struct SideloaderApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var pairing = PairingStore()
    @StateObject private var certificates = CertificateStore()
    @StateObject private var account = AccountStore()

    private let services: Services

    init() {
        services = Services()
        // Must be registered before launch finishes so iOS 26+ can continue pairing in the background.
        DevicePairingService.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .environmentObject(library)
                .environmentObject(pairing)
                .environmentObject(certificates)
                .environmentObject(account)
                .environmentObject(services.appleAccount)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // "Open in…" from Files or Safari
                    if url.pathExtension.lowercased() == "ipa" {
                        try? library.importIPA(from: url)
                    }
                }
        }
    }
}
