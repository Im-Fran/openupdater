<div align="center">

# 🔄 OpenUpdater

**Auto-updates for native macOS apps, powered by GitHub Releases.**

[![CI](https://img.shields.io/github/actions/workflow/status/Im-Fran/openupdater/ci.yml?branch=dev&label=CI)](https://github.com/Im-Fran/openupdater/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Im-Fran/openupdater)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-F05138)](https://swift.org/package-manager/)
[![Last commit](https://img.shields.io/github/last-commit/Im-Fran/openupdater)](https://github.com/Im-Fran/openupdater/commits/dev)

**English** · [Español](README.es.md)

</div>

---

## 📖 Overview

OpenUpdater is a Swift package that keeps your macOS app up to date using the releases you already publish on GitHub. No appcast server, no XML feed: tag a release, upload a signed `.zip`, and your users get the update.

It is written in Swift with a SwiftUI interface. It checks for new versions on a schedule the user picks (daily, weekly or monthly) and shows the release notes. The user can then install right away or on the next launch.

Every update is verified twice before it touches the disk: an **Ed25519 signature** of the zip, and a **code-signature check**. The code-signature check requires the new app to match the bundle ID and Team ID of the one currently running. The UI ships in **English** and **Spanish (Latin America)**.

---

## ✨ Features

- **GitHub Releases as the feed:** reads the repo's releases through the GitHub API and picks the newest non-draft version.
- **Install now or on next launch:** "Install and Relaunch" swaps the app and reopens it. "Install on Next Launch" stages the update and applies it the next time the app starts.
- **Scheduled checks:** daily, weekly or monthly, plus a manual "Check Now".
- **Signed updates:** Ed25519 signatures (CryptoKit) plus designated-requirement validation (Security framework).
- **Pre-release channel:** users can opt in to beta releases.
- **Drop-in SwiftUI UI:** an update window and an `UpdaterSettingsView` for your `Settings` scene.
- **Localized:** English and Spanish (es-419) via a String Catalog.
- **Zero dependencies:** only Apple frameworks.
- **CLI included:** `openupdater-cli` generates keys and signs release zips.

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 (Swift Package Manager) |
| UI | SwiftUI + AppKit (`NSWindow` / `NSHostingController`) |
| Crypto | CryptoKit (Curve25519 / Ed25519), Security (code signing) |
| Localization | String Catalog (`.xcstrings`): `en`, `es-419` |
| Tests | Swift Testing |

---

## 📋 Requirements

- **macOS 14** or later (deployment target of the host app)
- **Xcode 16** or later (Swift 6 tools)
- A **non-sandboxed** app, signed with a **Developer ID**
- A **public** GitHub repository for releases

---

## 🚀 Getting Started

### 1. Add the package

In Xcode: **File › Add Package Dependencies…** → `https://github.com/Im-Fran/openupdater`, product **OpenUpdater**.

Or in `Package.swift`:

```swift
.package(url: "https://github.com/Im-Fran/openupdater", branch: "dev"),
// target dependencies:
.product(name: "OpenUpdater", package: "openupdater"),
```

### 2. Generate signing keys

```bash
git clone https://github.com/Im-Fran/openupdater.git
cd openupdater
swift run openupdater-cli generate-keys
```

The **public key** goes into your app. Keep the **private key** secret, for example in a password manager and as a CI secret.

### 3. Wire it into your app

```swift
import OpenUpdater
import SwiftUI

@main
struct MyApp: App {
    @State private var updater = Updater(repo: "owner/MyApp", publicKey: "<base64 public key>")

    init() { updater.start() }

    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") { updater.checkNow() }
                }
            }
        Settings { UpdaterSettingsView(updater: updater) }
    }
}
```

`start()` does two things. First it installs any update staged for "next launch" and relaunches. Otherwise it starts the automatic check schedule.

> 🤖 Using an AI coding agent? Point it to [AGENT_SETUP.md](AGENT_SETUP.md). It is a step-by-step setup guide written for agents.

---

## 📦 Publishing a Release

1. Bump `CFBundleShortVersionString` (e.g. `1.2.0`), then archive, sign with your Developer ID and notarize.
2. Zip and sign the app:

   ```bash
   ditto -c -k --keepParent MyApp.app MyApp.zip
   swift run openupdater-cli sign MyApp.zip private.key
   # or: OPENUPDATER_PRIVATE_KEY=<key> swift run openupdater-cli sign MyApp.zip
   ```

3. Publish both files under a tag that matches the version (`v` prefix optional):

   ```bash
   gh release create v1.2.0 MyApp.zip MyApp.zip.sig --notes "What's new…"
   ```

   Add `--prerelease` to ship only to users who enabled pre-release versions.

---

## ⚙️ Configuration

These user preferences are stored in `UserDefaults` and exposed as properties on `Updater`. `UpdaterSettingsView` binds to them.

| Property | Default | Description |
|--------|---------|-------------|
| `automaticChecks` | `true` | Check for updates in the background |
| `frequency` | `.daily` | `.daily`, `.weekly` or `.monthly` |
| `includePrereleases` | `false` | Also offer GitHub pre-releases |

| Environment variable | Used by | Description |
|----------|-------------|---------|
| `OPENUPDATER_PRIVATE_KEY` | `openupdater-cli sign` | Base64 private key, used when no key file is passed |

---

## 🧪 Development

```bash
swift build   # build the library and CLI
swift test    # run the test suite
```

```
Sources/OpenUpdater/       Updater, GitHub API, installer, SwiftUI views, Localizable.xcstrings
Sources/openupdater-cli/   generate-keys / sign
Tests/OpenUpdaterTests/    version comparison, scheduling, signatures, release selection
```

---

## ⚠️ Limitations

- The running app needs a stable signature (Developer ID). Ad-hoc signed builds can't validate updates.
- The app's folder must be writable by the user, since there is no admin prompt. Apps run from a translocated location (e.g. Downloads) must be moved to Applications first.
- Public repositories only. The unauthenticated GitHub API allows 60 requests per hour per IP.
- Only `.zip` assets are supported.

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines and the project layout.

Quick workflow:
1. Fork the repo
2. Create a branch: `git checkout -b feat/your-feature`
3. Commit using [Conventional Commits](https://www.conventionalcommits.org): `git commit -m "feat: add your feature"`
4. Make sure `swift test` passes, then push and open a PR

Please follow the [Code of Conduct](.github/CODE_OF_CONDUCT.md).

---

## 🔒 Security

Found a vulnerability? Please read the [Security Policy](.github/SECURITY.md) and report it privately. Don't open a public issue.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.

---

<div align="center">
Made with ☕ by <a href="https://franciscosolis.cl">Fran</a>
</div>
