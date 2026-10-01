# OpenUpdater — setup guide for AI agents

Follow these steps to add OpenUpdater to a native macOS app (Swift/SwiftUI). Do them in order and
verify each one. Ask the user for anything marked **ASK**.

## 0. Preconditions (check, don't assume)

- macOS deployment target **14.0+**. If lower, **ASK** before raising it.
- The app is **not sandboxed** (`com.apple.security.app-sandbox` absent or `false` in the `.entitlements`). If sandboxed, stop and tell the user OpenUpdater doesn't support it.
- The app's source lives in a **public** GitHub repo, or releases are published to one. **ASK** for `owner/name`.
- Release builds are signed with a **Developer ID** (stable Team ID). Ad-hoc builds can't validate updates.
- `CFBundleShortVersionString` follows numeric versions (`1.2.0`, optional `-beta.N` suffix).

## 1. Add the dependency

Xcode project: add package `https://github.com/Im-Fran/openupdater` (product `OpenUpdater`) to the app target.
SwiftPM app: add to `Package.swift`:

```swift
.package(url: "https://github.com/Im-Fran/openupdater", branch: "main"),
// target dependencies:
.product(name: "OpenUpdater", package: "openupdater"),
```

## 2. Generate the signing keys

```sh
git clone https://github.com/Im-Fran/openupdater /tmp/openupdater
swift run --package-path /tmp/openupdater openupdater-cli generate-keys
```

- The **public key** goes into the app code (step 3). It is not secret.
- The **private key** must NEVER be committed. Give it to the user and tell them to store it in their password manager and as the CI secret `OPENUPDATER_PRIVATE_KEY`. Add `*.key` to `.gitignore` if you write it to a file.

## 3. Wire the updater

Create **one** `Updater` for the whole app lifetime and call `start()` once at launch.

SwiftUI `App`:

```swift
import OpenUpdater
import SwiftUI

@main
struct MyApp: App {
    @State private var updater = Updater(repo: "owner/MyApp", publicKey: "<PUBLIC KEY>")

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

AppKit `NSApplicationDelegate`: store `let updater = Updater(...)` as a property, call `updater.start()` in
`applicationDidFinishLaunching(_:)`, and wire a "Check for Updates…" menu item to `updater.checkNow()`.
Embed `UpdaterSettingsView(updater:)` with an `NSHostingView` in the preferences window.

If the app already has a `Settings` scene, add `UpdaterSettingsView` as a tab or section instead of replacing it.

## 4. Release pipeline

Each release must contain **both** `<Name>.zip` and `<Name>.zip.sig`, and the tag must match
`CFBundleShortVersionString` (`v` prefix optional).

```sh
ditto -c -k --keepParent MyApp.app MyApp.zip       # after signing + notarizing MyApp.app
swift run --package-path /tmp/openupdater openupdater-cli sign MyApp.zip   # reads OPENUPDATER_PRIVATE_KEY
gh release create v1.2.0 MyApp.zip MyApp.zip.sig --notes "…"
```

Use `--prerelease` for beta builds (only users with "Include pre-release versions" on get them).
If the project has a GitHub Actions release workflow, add the `ditto` + `sign` steps there and upload
both files.

## 5. Verify

1. Build the app; it must compile with no new warnings.
2. Run it, open Settings: the updater section shows the toggle, frequency picker and "Check Now".
3. "Check Now" with no newer release → "You're up to date!".
4. Full test (if the user agrees): publish a higher version, run the old build from `/Applications`,
   "Check Now" → "Install and Relaunch" must relaunch on the new version.
5. Spanish UI: run with `-AppleLanguages "(es-419)"`.

## Don'ts

- Don't create multiple `Updater` instances or call `start()` more than once.
- Don't commit the private key or put it in the app.
- Don't ship `.dmg` assets — only `.zip` is supported.
- Don't change the `OpenUpdater.*` keys in `UserDefaults`; they hold the user's preferences.
