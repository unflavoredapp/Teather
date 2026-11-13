import SwiftUI

// MOCKUP ONLY: this helper app does nothing. It reproduces the layout and
// flow of a helper screen (Waiting to start -> Start -> log -> Done) with
// animated placeholder text. It never reads, decrypts or writes any app.

struct HelperJob: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var version: String
    var symbol: String
    var colorName: String
    var autostart = false

    static let sample = HelperJob(name: "Sample Racer", version: "2.7.1", symbol: "car.fill", colorName: "red")

    /// Parses sideloaderhelper://decrypt?name=…&version=…&symbol=…&color=…
    init?(url: URL) {
        guard url.scheme == "sideloaderhelper",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func value(_ key: String) -> String? { items.first { $0.name == key }?.value }
        guard let name = value("name") else { return nil }
        self.name = name
        self.version = value("version") ?? "?"
        self.symbol = value("symbol") ?? "app.fill"
        self.colorName = value("color") ?? "blue"
        self.autostart = value("autostart") == "1"
    }

    init(name: String, version: String, symbol: String, colorName: String) {
        self.name = name
        self.version = version
        self.symbol = symbol
        self.colorName = colorName
    }

    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        default: return .blue
        }
    }
}

@main
struct SideloaderHelperApp: App {
    @State private var job = HelperJob.sample

    var body: some Scene {
        WindowGroup {
            HelperView(job: job)
                .id(job.id) // new job from a URL resets the screen to "Waiting to start"
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if let parsed = HelperJob(url: url) { job = parsed }
                }
        }
    }
}
