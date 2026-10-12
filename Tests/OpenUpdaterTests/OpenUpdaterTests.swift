import CryptoKit
import Foundation
import Testing
@testable import OpenUpdater

@Test func versionComparison() {
    #expect(isNewer("v1.10.0", than: "1.9.2"))
    #expect(!isNewer("1.2", than: "1.2.0"))
    #expect(isNewer("1.2.0", than: "1.2.0-beta.3"))
    #expect(isNewer("1.2.0-beta.10", than: "1.2.0-beta.9"))
    #expect(!isNewer("1.0.0", than: "1.0.1"))
    #expect(isNewer("1.4.1+2", than: "1.4.0"))
    #expect(!isNewer("1.4.0+7", than: "1.4.0"))
    #expect(isNewer("1.4.0", than: "1.4.0-beta.1+3"))
    #expect(isNewer("1.4.1+6", than: "1.4.1+3"))
    #expect(isNewer("1.4.1+10", than: "1.4.1+9"))
    #expect(!isNewer("1.4.1+3", than: "1.4.1+6"))
    #expect(!isNewer("1.4.0+9", than: "1.4.1+1"))
    #expect(isNewer("1.4.0-beta.1+2", than: "1.4.0-beta.1+1"))
}

@Test func frequencyDue() {
    let now = Date()
    #expect(Updater.isDue(lastCheck: nil, frequency: .daily, now: now))
    #expect(!Updater.isDue(lastCheck: now.addingTimeInterval(-3600), frequency: .daily, now: now))
    #expect(Updater.isDue(lastCheck: now.addingTimeInterval(-86_400), frequency: .daily, now: now))
    #expect(!Updater.isDue(lastCheck: now.addingTimeInterval(-3 * 86_400), frequency: .weekly, now: now))
    #expect(Updater.isDue(lastCheck: now.addingTimeInterval(-31 * 86_400), frequency: .monthly, now: now))
}

@Test func ed25519Signature() throws {
    let key = Curve25519.Signing.PrivateKey()
    let pub = key.publicKey.rawRepresentation.base64EncodedString()
    let data = Data("zip contents".utf8)
    let sig = try key.signature(for: data).base64EncodedString()
    #expect(Installer.verifySignature(data, signature: sig + "\n", publicKey: pub))
    #expect(!Installer.verifySignature(Data("tampered".utf8), signature: sig, publicKey: pub))
    #expect(!Installer.verifySignature(data, signature: "garbage", publicKey: pub))
}

@Test func releaseSelection() throws {
    let json = """
    [
      {"tag_name":"v2.0.0-beta.1","body":"","draft":false,"prerelease":true,
       "assets":[{"name":"App.zip","browser_download_url":"https://x/App.zip"}]},
      {"tag_name":"v1.1.0","body":"notes","draft":false,"prerelease":false,
       "assets":[{"name":"App.zip","browser_download_url":"https://x/App.zip"},
                 {"name":"App.zip.sig","browser_download_url":"https://x/App.zip.sig"}]},
      {"tag_name":"v3.0.0","body":"","draft":true,"prerelease":false,
       "assets":[{"name":"App.zip","browser_download_url":"https://x/App.zip"}]}
    ]
    """
    let releases = try JSONDecoder().decode([Release].self, from: Data(json.utf8))
    let stable = try #require(latestRelease(in: releases, includePrereleases: false))
    #expect(stable.version == "1.1.0")
    #expect(stable.signature?.name == "App.zip.sig")
    #expect(latestRelease(in: releases, includePrereleases: true)?.version == "2.0.0-beta.1")
}

@Test func rejectsDowngrades() throws {
    func app(_ version: String, build: String? = nil) throws -> URL {
        let app = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "My.app")
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": version, "CFBundleVersion": build].compactMapValues { $0 }, format: .xml, options: 0)
        try plist.write(to: contents.appending(path: "Info.plist"))
        return app
    }
    #expect(Installer.isUpgrade(try app("1.3.0"), from: "1.2.0"))
    #expect(!Installer.isUpgrade(try app("1.1.0"), from: "1.2.0"))
    #expect(!Installer.isUpgrade(try app("1.2.0"), from: "1.2.0"))
    #expect(Installer.isUpgrade(try app("1.2.0", build: "6"), from: "1.2.0+3"))
    #expect(!Installer.isUpgrade(try app("1.2.0", build: "3"), from: "1.2.0+6"))
}
