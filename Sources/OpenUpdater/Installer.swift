import CryptoKit
import Foundation
import Security

enum Installer {
    static func verifySignature(_ data: Data, signature: String, publicKey: String) -> Bool {
        guard let keyData = Data(base64Encoded: publicKey),
              let sig = Data(base64Encoded: signature.trimmingCharacters(in: .whitespacesAndNewlines)),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        else { return false }
        return key.isValidSignature(sig, for: data)
    }

    /// The new app must satisfy the running app's designated requirement (same bundle ID + Team ID).
    // ponytail: an ad-hoc signed running app has a cdhash-based requirement, so updates fail; sign with a Developer ID.
    static func matchesCurrentSignature(_ app: URL) -> Bool {
        var current: SecStaticCode?, requirement: SecRequirement?, candidate: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &current) == errSecSuccess, let current,
              SecCodeCopyDesignatedRequirement(current, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let candidate
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess
    }

    static var stagingRoot: URL {
        URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "OpenUpdater")
            .appending(path: "OpenUpdater")
    }

    /// Downloads, verifies and extracts the release. Returns the staged `.app`.
    static func prepare(_ release: Release, publicKey: String, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard let zip = release.zip, let sig = release.signature else { throw UpdateError.missingAsset }
        let fm = FileManager.default
        let dir = stagingRoot.appending(path: release.version)
        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let (sigData, _) = try await URLSession.shared.data(from: sig.url)
        let (tmp, response) = try await URLSession.shared.download(from: zip.url, delegate: ProgressObserver(progress))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.network }
        let zipURL = dir.appending(path: zip.name)
        try fm.moveItem(at: tmp, to: zipURL)

        let data = try Data(contentsOf: zipURL, options: .mappedIfSafe)
        guard verifySignature(data, signature: String(decoding: sigData, as: UTF8.self), publicKey: publicKey) else {
            throw UpdateError.badSignature
        }
        try run("/usr/bin/ditto", "-x", "-k", zipURL.path, dir.path)
        try? fm.removeItem(at: zipURL)

        guard let app = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" })
        else { throw UpdateError.missingAsset }
        guard matchesCurrentSignature(app) else { throw UpdateError.badCodeSignature }
        try? run("/usr/bin/xattr", "-dr", "com.apple.quarantine", app.path)
        return app
    }

    /// Spawns a detached shell that waits for this process to exit, swaps the bundles and relaunches.
    /// The caller must terminate the app right after.
    // ponytail: no privileged helper; fails if the user can't write to the app's folder.
    static func installAndRelaunch(_ newApp: URL) throws {
        let dest = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: dest.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable
        }
        let script = """
        while kill -0 "$0" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.old"
        if mv "$2" "$2.old"; then
          if mv "$1" "$2"; then rm -rf "$2.old"; else mv "$2.old" "$2"; fi
        fi
        rm -rf "$(dirname "$1")"
        open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "\(ProcessInfo.processInfo.processIdentifier)", newApp.path, dest.path]
        try process.run()
    }

    private static func run(_ tool: String, _ args: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.missingAsset }
    }
}

private final class ProgressObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Double) -> Void
    var observation: NSKeyValueObservation?

    init(_ onProgress: @escaping @Sendable (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [onProgress] progress, _ in
            onProgress(progress.fractionCompleted)
        }
    }
}
