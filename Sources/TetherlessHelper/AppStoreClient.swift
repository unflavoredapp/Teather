import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AppStoreClient {
    func lookup(term: String, storefront: String = "us") async throws -> [AppMetadata] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        if term.contains(".") && !term.allSatisfy(\.isNumber) { components.queryItems = [URLQueryItem(name: "bundleId", value: term)] }
        else { components.queryItems = [URLQueryItem(name: "id", value: term)] }
        components.queryItems?.append(URLQueryItem(name: "country", value: storefront.lowercased()))
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ProcessRunnerError.failed("App Store lookup returned an HTTP error") }
        let decoded = try JSONDecoder().decode(LookupEnvelope.self, from: data)
        return decoded.results.map { item in
            AppMetadata(appID: String(item.trackId), bundleID: item.bundleId, name: item.trackName,
                        version: item.version, minimumOSVersion: item.minimumOsVersion,
                        seller: item.sellerName, artworkURL: item.artworkUrl512 ?? item.artworkUrl100,
                        trackViewURL: item.trackViewUrl, storefront: storefront.lowercased())
        }
    }
}
private struct LookupEnvelope: Decodable { let results: [LookupItem] }
private struct LookupItem: Decodable {
    let trackId: Int64; let bundleId: String; let trackName: String
    let version: String?; let minimumOsVersion: String?; let sellerName: String?
    let artworkUrl512: String?; let artworkUrl100: String?; let trackViewUrl: String?
}

/// Deliberately stores descriptive account metadata only. Apple passwords, cookies,
/// DSID authentication tokens and FairPlay key material are not accepted by this service.
struct AppleAccountProfile: Codable {
    let label: String
    let storefront: String
    let accountOwnerConfirmed: Bool
}
