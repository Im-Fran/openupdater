import Foundation

public struct Release: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let url: URL
        enum CodingKeys: String, CodingKey { case name, url = "browser_download_url" }
    }

    public let tagName: String
    public let body: String?
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
    enum CodingKeys: String, CodingKey { case tagName = "tag_name", body, draft, prerelease, assets }

    public var version: String { tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName }
    var zip: Asset? { assets.first { $0.name.hasSuffix(".zip") } }
    var signature: Asset? { zip.flatMap { zip in assets.first { $0.name == zip.name + ".sig" } } }
}

/// Compares `1.10.0` > `1.9.2`, `1.2` == `1.2.0`, and `1.2.0` > `1.2.0-beta.3` > `1.2.0-beta.2`.
func isNewer(_ a: String, than b: String) -> Bool {
    func split(_ v: String) -> ([Int], String?) {
        let v = v.hasPrefix("v") ? v.dropFirst() : Substring(v)
        let parts = v.split(separator: "-", maxSplits: 1)
        let core = parts.first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? []
        return (core, parts.count > 1 ? String(parts[1]) : nil)
    }
    let (ac, ap) = split(a), (bc, bp) = split(b)
    for i in 0..<max(ac.count, bc.count) {
        let l = i < ac.count ? ac[i] : 0, r = i < bc.count ? bc[i] : 0
        if l != r { return l > r }
    }
    switch (ap, bp) {
    case (nil, .some): return true
    case let (x?, y?): return x.compare(y, options: .numeric) == .orderedDescending
    default: return false
    }
}

func latestRelease(in releases: [Release], includePrereleases: Bool) -> Release? {
    releases
        .filter { !$0.draft && (includePrereleases || !$0.prerelease) && $0.zip != nil }
        .max { isNewer($1.version, than: $0.version) }
}

func fetchReleases(repo: String) async throws -> [Release] {
    guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=20") else {
        throw UpdateError.network
    }
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.network }
    return try JSONDecoder().decode([Release].self, from: data)
}

enum UpdateError: LocalizedError {
    case network, missingAsset, badSignature, badCodeSignature, notWritable

    var errorDescription: String? {
        switch self {
        case .network: String(localized: "Could not reach GitHub. Check your internet connection.", bundle: .module)
        case .missingAsset: String(localized: "The release does not contain a valid update.", bundle: .module)
        case .badSignature: String(localized: "The update signature is invalid.", bundle: .module)
        case .badCodeSignature: String(localized: "The update is not signed by the same developer.", bundle: .module)
        case .notWritable: String(localized: "The app's folder is not writable. Move the app to Applications and try again.", bundle: .module)
        }
    }
}
