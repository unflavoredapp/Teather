import Foundation

// MARK: - Apple Developer Services 2 client
//
// Real client for the free-account developer API that AltStore-style signing
// uses. Every call here is a production Apple endpoint. Requests are property
// lists POSTed to developerservices2.apple.com with the GrandSlam token and
// anisette headers; responses are plists. Nothing here is mocked.

struct DeveloperTeam: Identifiable, Hashable {
    let id: String          // teamId, e.g. "GVZJWHFTS9"
    let name: String        // "Rodger Williams"
    let type: String        // "Individual"
}

struct SigningCertificate: Identifiable, Hashable {
    let id: String
    let name: String        // "iOS Development: Rodger Williams"
    let serialNumber: String
    let expiry: Date?
    /// DER of the certificate, when the API returns it.
    let data: Data?
}

struct AppID: Identifiable, Hashable {
    let id: String          // appIdId
    let name: String        // "Tetherless App"
    let identifier: String  // "com.example.app.TEAMID"
}

struct RegisteredDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let udid: String
}

/// Thin HTTPS/plist transport + the specific developer-services operations.
struct AppleDeveloperServicesClient {
    let session: AppleSession
    var urlSession: URLSession = .shared

    private let base = URL(string: "https://developerservices2.apple.com/services/QH65B2/")!
    private let protocolVersion = "QH65B2"

    // MARK: Transport

    private func request(_ action: String, parameters: [String: Any] = [:]) async throws -> [String: Any] {
        let url = base.appendingPathComponent(action)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        var body: [String: Any] = [
            "clientId": "XABBG36SBA",
            "protocolVersion": protocolVersion,
            "requestId": UUID().uuidString.uppercased(),
            "myacinfo": session.authToken
        ]
        body.merge(parameters) { _, new in new }

        req.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        req.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        req.setValue("XCode", forHTTPHeaderField: "X-Xcode-Version")
        req.setValue(session.authToken, forHTTPHeaderField: "X-Apple-GS-Token")
        for (k, v) in session.anisette.headers { req.setValue(v, forHTTPHeaderField: k) }

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.failed("Developer Services returned a non-OK status.")
        }
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw ServiceError.failed("Couldn't parse the Developer Services response.")
        }
        if let code = plist["resultCode"] as? Int, code != 0 {
            let message = (plist["userString"] as? String) ?? (plist["resultString"] as? String) ?? "Developer Services error \(code)."
            throw ServiceError.failed(message)
        }
        return plist
    }

    // MARK: Operations

    func teams() async throws -> [DeveloperTeam] {
        let plist = try await request("listTeams.action")
        let raw = (plist["teams"] as? [[String: Any]]) ?? []
        return raw.compactMap { t in
            guard let id = t["teamId"] as? String else { return nil }
            return DeveloperTeam(id: id,
                                 name: (t["name"] as? String) ?? id,
                                 type: ((t["type"] as? String) ?? "Individual"))
        }
    }

    func certificates(teamID: String) async throws -> [SigningCertificate] {
        let plist = try await request("ios/listAllDevelopmentCerts.action", parameters: ["teamId": teamID])
        let raw = (plist["certificates"] as? [[String: Any]]) ?? []
        return raw.map { c in
            SigningCertificate(
                id: (c["certificateId"] as? String) ?? UUID().uuidString,
                name: (c["name"] as? String) ?? "iOS Development",
                serialNumber: (c["serialNumber"] as? String) ?? "",
                expiry: c["expirationDate"] as? Date,
                data: c["certContent"] as? Data)
        }
    }

    /// Submits a CSR and returns the issued development certificate.
    func submitCertificate(csr: Data, teamID: String, machineName: String) async throws -> SigningCertificate {
        guard let csrString = String(data: csr, encoding: .utf8) else {
            throw ServiceError.failed("Invalid CSR encoding.")
        }
        let plist = try await request("ios/submitDevelopmentCSR.action", parameters: [
            "teamId": teamID,
            "csrContent": csrString,
            "machineId": session.anisette.deviceUniqueIdentifier,
            "machineName": machineName
        ])
        guard let c = plist["certRequest"] as? [String: Any] else {
            throw ServiceError.failed("Apple didn't return a certificate.")
        }
        return SigningCertificate(
            id: (c["certificateId"] as? String) ?? UUID().uuidString,
            name: (c["name"] as? String) ?? "iOS Development",
            serialNumber: (c["serialNumber"] as? String) ?? "",
            expiry: c["expirationDate"] as? Date,
            data: c["certContent"] as? Data)
    }

    func revokeCertificate(id: String, teamID: String) async throws {
        _ = try await request("ios/revokeDevelopmentCert.action", parameters: [
            "teamId": teamID, "serialNumber": id
        ])
    }

    func appIDs(teamID: String) async throws -> [AppID] {
        let plist = try await request("ios/listAppIds.action", parameters: ["teamId": teamID])
        let raw = (plist["appIds"] as? [[String: Any]]) ?? []
        return raw.map { a in
            AppID(id: (a["appIdId"] as? String) ?? UUID().uuidString,
                  name: (a["name"] as? String) ?? "App",
                  identifier: (a["identifier"] as? String) ?? "")
        }
    }

    /// Registers an App ID, returning its record (needed to make a profile).
    func registerAppID(name: String, bundleID: String, teamID: String) async throws -> AppID {
        let plist = try await request("ios/addAppId.action", parameters: [
            "teamId": teamID, "name": name, "identifier": bundleID
        ])
        guard let a = plist["appId"] as? [String: Any] else {
            throw ServiceError.failed("Couldn't register the App ID.")
        }
        return AppID(id: (a["appIdId"] as? String) ?? UUID().uuidString,
                     name: (a["name"] as? String) ?? name,
                     identifier: (a["identifier"] as? String) ?? bundleID)
    }

    func devices(teamID: String) async throws -> [RegisteredDevice] {
        let plist = try await request("ios/listDevices.action", parameters: ["teamId": teamID])
        let raw = (plist["devices"] as? [[String: Any]]) ?? []
        return raw.map { d in
            RegisteredDevice(id: (d["deviceId"] as? String) ?? UUID().uuidString,
                             name: (d["name"] as? String) ?? "Device",
                             udid: (d["deviceNumber"] as? String) ?? "")
        }
    }

    @discardableResult
    func registerDevice(name: String, udid: String, teamID: String) async throws -> RegisteredDevice {
        let plist = try await request("ios/addDevice.action", parameters: [
            "teamId": teamID, "name": name, "deviceNumber": udid
        ])
        let d = (plist["device"] as? [String: Any]) ?? [:]
        return RegisteredDevice(id: (d["deviceId"] as? String) ?? UUID().uuidString,
                                name: (d["name"] as? String) ?? name,
                                udid: (d["deviceNumber"] as? String) ?? udid)
    }

    /// Downloads the `.mobileprovision` for an App ID + the current device/cert.
    func provisioningProfile(appIDIdentifier: String, teamID: String) async throws -> Data {
        let plist = try await request("ios/downloadTeamProvisioningProfile.action", parameters: [
            "teamId": teamID, "appIdId": appIDIdentifier
        ])
        guard let profile = plist["provisioningProfile"] as? [String: Any],
              let data = profile["encodedProfile"] as? Data else {
            throw ServiceError.failed("Apple didn't return a provisioning profile.")
        }
        return data
    }
}
