import Foundation

@main
struct TetherlessHelperMain {
    static func main() async {
        do { try await run(Array(CommandLine.arguments.dropFirst())) }
        catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    static func run(_ args: [String]) async throws {
        guard let command = args.first else { printUsage(); return }
        let rest = Array(args.dropFirst())
        let devices = DeviceManager(), ipa = IPAManager(), store = AppStoreClient()
        switch command {
        case "version": print("TetherlessHelper 0.1.0")
        case "doctor":
            let checks = [
                DoctorCheck(name: "Swift runtime", available: true, detail: "Built with Swift 6"),
                DoctorCheck(name: "usbmuxd", available: ProcessRunner.find("idevice_id") != nil, detail: ProcessRunner.find("idevice_id") ?? "Install libimobiledevice-utils and usbmuxd"),
                DoctorCheck(name: "ideviceinfo", available: ProcessRunner.find("ideviceinfo") != nil, detail: ProcessRunner.find("ideviceinfo") ?? "Install libimobiledevice-utils"),
                DoctorCheck(name: "idevicepair", available: ProcessRunner.find("idevicepair") != nil, detail: ProcessRunner.find("idevicepair") ?? "Install libimobiledevice-utils"),
                DoctorCheck(name: "unzip", available: ProcessRunner.find("unzip") != nil, detail: ProcessRunner.find("unzip") ?? "Install unzip"),
                DoctorCheck(name: "zip", available: ProcessRunner.find("zip") != nil, detail: ProcessRunner.find("zip") ?? "Install zip"),
                DoctorCheck(name: "sha256sum", available: ProcessRunner.find("sha256sum") != nil, detail: ProcessRunner.find("sha256sum") ?? "Install coreutils")
            ]
            try printJSON(DoctorResponse(checks: checks))
        case "devices": try printJSON(devices.listDevices())
        case "pair":
            guard let udid = rest.first else { throw ProcessRunnerError.failed("Usage: tetherless-helper pair <UDID>") }
            print(try devices.pair(udid: udid))
        case "lookup":
            guard let term = rest.first else { throw ProcessRunnerError.failed("Usage: tetherless-helper lookup <bundle-id-or-app-id> [country]") }
            try printJSON(await store.lookup(term: term, storefront: rest.count > 1 ? rest[1] : "us"))
        case "inspect":
            guard let path = rest.first else { throw ProcessRunnerError.failed("Usage: tetherless-helper inspect <app.ipa>") }
            try printJSON(ipa.inspect(path: path))
        case "extract":
            guard rest.count >= 2 else { throw ProcessRunnerError.failed("Usage: tetherless-helper extract <app.ipa> <destination>") }
            try ipa.extract(path: rest[0], to: rest[1]); print("Extracted to \(rest[1])")
        case "package":
            guard rest.count >= 2 else { throw ProcessRunnerError.failed("Usage: tetherless-helper package <Payload/App.app> <output.ipa>") }
            try ipa.package(appDirectory: rest[0], output: rest[1]); print("Created \(rest[1])")
        case "serve":
            let host = option("--host", in: rest) ?? "127.0.0.1"
            let port = UInt16(option("--port", in: rest) ?? "8787") ?? 8787
            guard let token = ProcessInfo.processInfo.environment["TETHERLESS_API_TOKEN"], token.count >= 32 else {
                throw ProcessRunnerError.failed("Set TETHERLESS_API_TOKEN to a random secret of at least 32 characters before starting the API")
            }
            let server = HTTPServer(host: host, port: port, token: token)
            try server.run()
        case "help", "--help", "-h": printUsage()
        default: throw ProcessRunnerError.failed("Unknown command: \(command). Run tetherless-helper help.")
        }
    }
    static func option(_ name: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: name), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
    static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value); print(String(decoding: data, as: UTF8.self))
    }
    static func printUsage() {
        print("""
        TetherlessHelper 0.1.0 — Debian Swift helper

        Commands:
          doctor                                      Check host dependencies
          devices                                     List connected iOS devices
          pair <UDID>                                 Pair with a device (confirm trust prompt)
          lookup <bundle-id-or-app-id> [country]      Public App Store metadata lookup
          inspect <app.ipa>                           Inspect IPA metadata and SHA-256
          extract <app.ipa> <destination>             Extract a validated IPA
          package <Payload/App.app> <output.ipa>      Package an extracted app as IPA
          serve [--host 127.0.0.1] [--port 8787]      Start authenticated JSON API
          version                                     Print version

        API token: export TETHERLESS_API_TOKEN to a random secret (32+ characters).
        """)
    }
}
