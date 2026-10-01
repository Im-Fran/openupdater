# OpenUpdater

Auto-updates for native macOS apps (Swift/SwiftUI) using **GitHub Releases**.
English and Spanish (Latin America) UI included.

- Checks daily, weekly or monthly (user-configurable), or on demand.
- Download, then **Install and Relaunch** now or **Install on Next Launch**.
- Updates are verified with an **Ed25519 signature** and must match the running app's **code signature** (same bundle ID + Team ID).
- Optional pre-release channel.

Requires macOS 14+. Non-sandboxed apps only.

## Integration

Add the package (`File › Add Package Dependencies…`) and:

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

`start()` installs an update staged for "next launch" (and relaunches), then runs the automatic check schedule.

## Keys

```sh
swift run openupdater-cli generate-keys
```

Put the public key in `Updater(publicKey:)`. Keep the private key secret (e.g. a CI secret `OPENUPDATER_PRIVATE_KEY`).

## Publishing a release

1. Bump `CFBundleShortVersionString` (e.g. `1.2.0`), archive, sign with your **Developer ID** and notarize.
2. Zip and sign:
   ```sh
   ditto -c -k --keepParent MyApp.app MyApp.zip
   swift run openupdater-cli sign MyApp.zip private.key   # or OPENUPDATER_PRIVATE_KEY=... 
   ```
3. Publish with a tag matching the version (`v` prefix optional):
   ```sh
   gh release create v1.2.0 MyApp.zip MyApp.zip.sig --notes "What's new…"
   ```
   Mark it as pre-release to ship only to users with "Include pre-release versions" on.

## Limitations

- The running app must be signed with a stable identity (Developer ID). Ad-hoc signed builds can't validate updates.
- The app's folder must be writable by the user (no admin prompt). Translocated apps (run from Downloads) must be moved to Applications first.
- Public repositories only (unauthenticated GitHub API: 60 requests/hour per IP).

## AI agents

Setting this up with an AI coding agent? Point it to [AGENT_SETUP.md](AGENT_SETUP.md).

## License

[GPL-3.0](LICENSE)
