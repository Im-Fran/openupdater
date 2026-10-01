import AppKit
import Observation
import SwiftUI

public enum CheckFrequency: String, CaseIterable, Identifiable, Sendable {
    case daily, weekly, monthly

    public var id: Self { self }

    var interval: TimeInterval {
        switch self {
        case .daily: 86_400
        case .weekly: 7 * 86_400
        case .monthly: 30 * 86_400
        }
    }
}

@MainActor @Observable
public final class Updater {
    public enum State: Equatable {
        case idle, checking, upToDate, available(Release), downloading(Double), scheduled, error(String)
    }

    private enum Key {
        static let auto = "OpenUpdater.automaticChecks"
        static let frequency = "OpenUpdater.frequency"
        static let prereleases = "OpenUpdater.includePrereleases"
        static let lastCheck = "OpenUpdater.lastCheck"
        static let pending = "OpenUpdater.pendingUpdatePath"
    }

    public let repo: String
    private let publicKey: String
    private let defaults: UserDefaults
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var window: NSWindow?

    public private(set) var state: State = .idle
    public private(set) var lastCheck: Date?
    public var automaticChecks: Bool { didSet { defaults.set(automaticChecks, forKey: Key.auto) } }
    public var frequency: CheckFrequency { didSet { defaults.set(frequency.rawValue, forKey: Key.frequency) } }
    public var includePrereleases: Bool { didSet { defaults.set(includePrereleases, forKey: Key.prereleases) } }

    /// - Parameters:
    ///   - repo: GitHub repository as `owner/name`.
    ///   - publicKey: Base64 Ed25519 public key from `openupdater-cli generate-keys`.
    public init(repo: String, publicKey: String, defaults: UserDefaults = .standard) {
        self.repo = repo
        self.publicKey = publicKey
        self.defaults = defaults
        automaticChecks = defaults.object(forKey: Key.auto) as? Bool ?? true
        frequency = defaults.string(forKey: Key.frequency).flatMap(CheckFrequency.init) ?? .daily
        includePrereleases = defaults.bool(forKey: Key.prereleases)
        lastCheck = defaults.object(forKey: Key.lastCheck) as? Date
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var appName: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? ProcessInfo.processInfo.processName
    }

    /// Installs an update staged for "next launch" (relaunching the app), otherwise starts the automatic check schedule.
    public func start() {
        Task {
            if installPendingUpdate() { return }
            checkIfDue()
            timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                Task { @MainActor in self.checkIfDue() }
            }
        }
    }

    /// User-initiated check: always shows the result window.
    public func checkNow() {
        Task { await check(userInitiated: true) }
    }

    public func install(now: Bool) {
        guard case .available(let release) = state else { return }
        state = .downloading(0)
        Task {
            do {
                let app = try await Installer.prepare(release, publicKey: publicKey) { p in
                    Task { @MainActor in
                        if case .downloading = self.state { self.state = .downloading(p) }
                    }
                }
                if now {
                    try Installer.installAndRelaunch(app)
                    NSApp.terminate(nil)
                } else {
                    defaults.set(app.path, forKey: Key.pending)
                    state = .scheduled
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    public func dismiss() {
        window?.close()
        if case .downloading = state { return }
        state = .idle
    }

    nonisolated static func isDue(lastCheck: Date?, frequency: CheckFrequency, now: Date = .now) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= frequency.interval
    }

    private func checkIfDue() {
        guard automaticChecks, Self.isDue(lastCheck: lastCheck, frequency: frequency) else { return }
        Task { await check(userInitiated: false) }
    }

    private func check(userInitiated: Bool) async {
        switch state {
        case .checking, .downloading: return
        default: break
        }
        state = .checking
        if userInitiated { showWindow() }
        do {
            let releases = try await fetchReleases(repo: repo)
            lastCheck = .now
            defaults.set(lastCheck, forKey: Key.lastCheck)
            if let release = latestRelease(in: releases, includePrereleases: includePrereleases),
               isNewer(release.version, than: currentVersion) {
                // Already staged for next launch: don't nag on background checks.
                if !userInitiated, defaults.string(forKey: Key.pending) != nil { state = .idle; return }
                state = .available(release)
                showWindow()
            } else {
                state = userInitiated ? .upToDate : .idle
            }
        } catch {
            state = userInitiated ? .error(error.localizedDescription) : .idle
        }
    }

    private func installPendingUpdate() -> Bool {
        guard let path = defaults.string(forKey: Key.pending) else { return false }
        defaults.removeObject(forKey: Key.pending)
        let app = URL(fileURLWithPath: path)
        // Skip if the user already updated manually to this version or newer.
        guard let version = Bundle(url: app)?.infoDictionary?["CFBundleShortVersionString"] as? String,
              isNewer(version, than: currentVersion)
        else {
            try? FileManager.default.removeItem(at: app.deletingLastPathComponent())
            return false
        }
        do {
            try Installer.installAndRelaunch(app)
            NSApp.terminate(nil)
            return true
        } catch {
            state = .error(error.localizedDescription)
            showWindow()
            return false
        }
    }

    private func showWindow() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: UpdateView(updater: self)))
            window.title = String(localized: "Software Update", bundle: .module)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
