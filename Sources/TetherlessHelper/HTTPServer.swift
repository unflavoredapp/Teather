import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

final class HTTPServer: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let token: String
    private let dataRoot: URL
    private let devices = DeviceManager()
    private let ipa = IPAManager()
    private let store = AppStoreClient()

    init(host: String, port: UInt16, token: String) {
        self.host = host; self.port = port; self.token = token
        let root = ProcessInfo.processInfo.environment["TETHERLESS_DATA_DIR"] ?? "/var/lib/tetherless-helper"
        self.dataRoot = URL(fileURLWithPath: root).standardizedFileURL
        try? FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
    }

    func run() throws {
        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard fd >= 0 else { throw ProcessRunnerError.failed("Unable to create API socket") }
        defer { _ = close(fd) }
        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        let parsed = host.withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        guard parsed == 1 else { throw ProcessRunnerError.failed("Bind host must be an IPv4 address, e.g. 127.0.0.1") }
        let bindResult = withUnsafePointer(to: &address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0, listen(fd, 32) == 0 else { throw ProcessRunnerError.failed("Unable to bind/listen on \(host):\(port): \(String(cString: strerror(errno)))") }
        print("TetherlessHelper listening on http://\(host):\(port)")
        while true {
            var peer = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &peer) { ptr in ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(fd, $0, &len) } }
            if client < 0 { continue }
            DispatchQueue.global().async { self.handle(client) }
        }
    }

    private func handle(_ client: Int32) {
        Task { [self] in
            defer { _ = close(client) }
            do {
                let request = try self.readRequest(client)
                let (status, contentType, body) = try await self.route(request)
                self.respond(client, status: status, contentType: contentType, body: body)
            } catch {
                let data = (try? self.encode(APIError(error: error.localizedDescription))) ?? Data("{\"error\":\"internal error\"}".utf8)
                self.respond(client, status: 400, contentType: "application/json", body: data)
            }
        }
    }

    private struct Request { let method: String; let target: String; let headers: [String: String]; let body: Data }
    private func readRequest(_ fd: Int32) throws -> Request {
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
        var headerEnd: Range<Data.Index>?
        var contentLength = 0
        while data.count < 2_000_000 {
            let n = recv(fd, &buffer, buffer.count, 0)
            if n <= 0 { throw ProcessRunnerError.failed("Client disconnected") }
            data.append(contentsOf: buffer[0..<n])
            if headerEnd == nil, let range = data.range(of: Data("\r\n\r\n".utf8)) {
                headerEnd = range
                let headerText = String(decoding: data[..<range.lowerBound], as: UTF8.self)
                for line in headerText.components(separatedBy: "\r\n").dropFirst() {
                    let p = line.split(separator: ":", maxSplits: 1)
                    if p.count == 2 && p[0].lowercased() == "content-length" { contentLength = Int(p[1].trimmingCharacters(in: .whitespaces)) ?? 0 }
                }
            }
            if let range = headerEnd, data.count >= range.upperBound + contentLength { break }
        }
        guard let range = headerEnd else { throw ProcessRunnerError.failed("Malformed HTTP request") }
        let headerText = String(decoding: data[..<range.lowerBound], as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let first = lines.first else { throw ProcessRunnerError.failed("Missing request line") }
        let bits = first.split(separator: " ")
        guard bits.count >= 2 else { throw ProcessRunnerError.failed("Malformed request line") }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let p = line.split(separator: ":", maxSplits: 1)
            if p.count == 2 { headers[p[0].lowercased()] = p[1].trimmingCharacters(in: .whitespaces) }
        }
        let bodyStart = range.upperBound
        let bodyEnd = min(data.count, bodyStart + contentLength)
        return Request(method: String(bits[0]), target: String(bits[1]), headers: headers, body: data.subdata(in: bodyStart..<bodyEnd))
    }

    private func route(_ r: Request) async throws -> (Int, String, Data) {
        let url = URLComponents(string: "http://localhost\(r.target)")!
        let path = url.path
        if r.method == "GET" && path == "/health" {
            return (200, "application/json", try encode(HealthResponse(name: "TetherlessHelper", version: "0.1.0", platform: "linux", capabilities: ["device-discovery", "device-pairing", "public-appstore-lookup", "ipa-inspection", "ipa-extraction", "ipa-packaging"])))
        }
        guard r.headers["authorization"] == "Bearer \(token)" else { return (401, "application/json", try encode(APIError(error: "Unauthorized: provide the configured bearer token"))) }
        if r.method == "GET" && path == "/v1/doctor" {
            let checks = ["idevice_id", "ideviceinfo", "idevicepair", "unzip", "zip", "sha256sum"].map { name in DoctorCheck(name: name, available: ProcessRunner.find(name) != nil, detail: ProcessRunner.find(name) ?? "not installed") }
            return (200, "application/json", try encode(DoctorResponse(checks: checks)))
        }
        if r.method == "GET" && path == "/v1/devices" { return (200, "application/json", try encode(devices.listDevices())) }
        if r.method == "GET" && path == "/v1/apps/lookup" {
            let term = url.queryItems?.first(where: { $0.name == "term" })?.value ?? ""
            let country = url.queryItems?.first(where: { $0.name == "country" })?.value ?? "us"
            guard !term.isEmpty else { throw ProcessRunnerError.failed("Missing term query parameter") }
            return (200, "application/json", try encode(await store.lookup(term: term, storefront: country)))
        }
        if r.method == "POST" && path == "/v1/ipa/inspect" {
            let input = try JSONDecoder().decode(PathRequest.self, from: r.body)
            let managed = try managedPath(input.path)
            return (200, "application/json", try encode(ipa.inspect(path: managed.path)))
        }
        if r.method == "POST" && path == "/v1/ipa/extract" {
            let input = try JSONDecoder().decode(ExtractRequest.self, from: r.body)
            let source = try managedPath(input.path), destination = try managedPath(input.destination)
            try ipa.extract(path: source.path, to: destination.path)
            return (200, "application/json", try encode(StatusResponse(status: "extracted", destination: destination.path)))
        }
        if r.method == "POST" && path == "/v1/ipa/package" {
            let input = try JSONDecoder().decode(PackageRequest.self, from: r.body)
            let app = try managedPath(input.appDirectory), output = try managedPath(input.output)
            try ipa.package(appDirectory: app.path, output: output.path)
            return (200, "application/json", try encode(StatusResponse(status: "packaged", destination: output.path)))
        }
        if r.method == "POST" && path.hasPrefix("/v1/devices/") && path.hasSuffix("/pair") {
            let udid = String(path.dropFirst("/v1/devices/".count).dropLast("/pair".count))
            guard !udid.isEmpty, !udid.contains("/") else { throw ProcessRunnerError.failed("Invalid device identifier") }
            let output = try devices.pair(udid: udid)
            return (200, "application/json", try encode(StatusResponse(status: "pair-command-complete", destination: output.trimmingCharacters(in: .whitespacesAndNewlines))))
        }
        return (404, "application/json", try encode(APIError(error: "Route not found")))
    }

    private func managedPath(_ raw: String) throws -> URL {
        let candidate = URL(fileURLWithPath: raw, relativeTo: dataRoot).standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let resolvedRoot = dataRoot.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard resolved.path == resolvedRoot.path || resolved.path.hasPrefix(rootPath) else { throw ProcessRunnerError.failed("File paths must stay inside TETHERLESS_DATA_DIR (\(resolvedRoot.path))") }
        return resolved
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
    private func respond(_ fd: Int32, status: Int, contentType: String, body: Data) {
        let reason = status == 200 ? "OK" : (status == 404 ? "Not Found" : (status == 401 ? "Unauthorized" : "Bad Request"))
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        _ = header.withCString { ptr in send(fd, ptr, strlen(ptr), 0) }
        body.withUnsafeBytes { raw in if let base = raw.baseAddress { _ = send(fd, base, raw.count, 0) } }
    }
}
private struct PathRequest: Decodable { let path: String }
private struct ExtractRequest: Decodable { let path: String; let destination: String }
private struct PackageRequest: Decodable { let appDirectory: String; let output: String }
private struct StatusResponse: Codable { let status: String; let destination: String }
