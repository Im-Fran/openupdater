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
.package(url: "https://github.com/Im-Fran/openupdater", branch: "dev"),
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

### 4.1 What every release MUST contain

OpenUpdater reads the GitHub release and expects exactly this. If anything is off, the update fails
(or is never offered).

| Item | Requirement |
|------|-------------|
| Tag | The app version with an optional `v` prefix: `v1.2.0` or `1.2.0`. It **must equal** the app's `CFBundleShortVersionString`. A tag that is higher than the bundle version causes an update loop. |
| Release state | Published, **not a draft**. Mark it **pre-release** for betas (`v1.3.0-beta.1`); only users with "Include pre-release versions" on will get it. |
| `<Name>.zip` | **Exactly one** `.zip` asset per release (the updater takes the first `.zip`). It must contain the **`.app` bundle directly at the root**: `MyApp.zip → MyApp.app/…`. No wrapping folder, no `.dmg`/`.pkg` inside, no extra `.app`. |
| `<Name>.zip.sig` | Ed25519 signature of **that exact zip**, named the zip's name plus `.sig` (`MyApp.zip.sig`). It is a base64 text file produced by `openupdater-cli sign`. |
| The `.app` inside | Signed with **Developer ID Application**, **hardened runtime**, **notarized and stapled**. Same bundle ID and Team ID as every previous release. |

Use asset names without spaces (`MyApp.zip`, not `My App.zip`).

Build the zip **only** with `ditto`:

```sh
ditto -c -k --sequesterRsrc --keepParent MyApp.app MyApp.zip
```

Don't use Finder's "Compress" or `zip -r`. They can drop extended attributes or symlinks, and that
breaks the code signature. `--keepParent` is what puts `MyApp.app` at the zip root.

### 4.2 Two signatures, two purposes

| Signature | Proves | Key / certificate | Where it lives |
|-----------|--------|-------------------|----------------|
| **Apple code signature** (Developer ID) | The app comes from the same developer. OpenUpdater checks the new app against the running app's *designated requirement*: same bundle ID and same Team ID. | "Developer ID Application" certificate from the Apple Developer account | Keychain / CI secret (`.p12`) |
| **Ed25519 signature** (OpenUpdater) | The zip downloaded from GitHub is exactly the one the developer published. | Private key from `openupdater-cli generate-keys` (step 2) | Password manager / CI secret `OPENUPDATER_PRIVATE_KEY` |

Both are required. Never change the bundle ID or the Team ID between releases: existing installs will
reject the update with "The update is not signed by the same developer."

### 4.3 Configure code signing (one time)

**ASK** the user whether they have a paid Apple Developer account and a **Developer ID Application**
certificate. Without one, OpenUpdater cannot work, so stop and tell them.

In the app target's Build Settings / Signing & Capabilities:

- **Team**: the user's team (`DEVELOPMENT_TEAM`).
- **Signing Certificate** for Release: `Developer ID Application` (`CODE_SIGN_IDENTITY`).
- **Hardened Runtime**: enabled (`ENABLE_HARDENED_RUNTIME = YES`). Notarization requires it.
- **App Sandbox**: disabled.
- **Bundle Identifier**: final; never change it after the first release.

Create `ExportOptions.plist` in the app repo:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TEAMID1234</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

For notarization on the user's Mac, store credentials once. It needs an app-specific password from
appleid.apple.com:

```sh
xcrun notarytool store-credentials notary --apple-id "<apple id>" --team-id TEAMID1234 --password "<app-specific password>"
```

### 4.4 Build, sign, notarize, zip, sign zip, publish (manual)

Run in this order. Each step depends on the previous one.

```sh
VERSION=1.2.0   # must equal CFBundleShortVersionString

# 1. Archive + export with Developer ID
xcodebuild -scheme MyApp -configuration Release -archivePath build/MyApp.xcarchive archive
xcodebuild -exportArchive -archivePath build/MyApp.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist

# 2. Notarize + staple the .app
ditto -c -k --keepParent build/export/MyApp.app build/notarize.zip
xcrun notarytool submit build/notarize.zip --keychain-profile notary --wait
xcrun stapler staple build/export/MyApp.app

# 3. Final zip (AFTER stapling, so the ticket is inside)
ditto -c -k --sequesterRsrc --keepParent build/export/MyApp.app build/MyApp.zip

# 4. Ed25519-sign the FINAL zip. Any change to the zip after this invalidates the signature.
swift run --package-path /tmp/openupdater openupdater-cli sign build/MyApp.zip   # uses OPENUPDATER_PRIVATE_KEY

# 5. Publish
gh release create "v$VERSION" build/MyApp.zip build/MyApp.zip.sig --title "v$VERSION" --notes "…"
#   add --prerelease for beta versions
```

### 4.5 Validate before publishing

Run all of these and check the expected output:

```sh
# The .app is at the zip root (first entry is "MyApp.app/")
unzip -l build/MyApp.zip | sed -n 4p

# Version matches the tag
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/export/MyApp.app/Contents/Info.plist

# Code signature valid, notarized
codesign --verify --deep --strict --verbose=2 build/export/MyApp.app   # "valid on disk", "satisfies its Designated Requirement"
spctl -a -t exec -vv build/export/MyApp.app                            # "accepted", "source=Notarized Developer ID"

# Designated requirement: identifier and team must be identical to the previous release
codesign -d -r- build/export/MyApp.app

# Ed25519 signature matches the public key embedded in the app
swift run --package-path /tmp/openupdater openupdater-cli verify build/MyApp.zip "<PUBLIC KEY>"   # "Signature OK"
```

### 4.6 GitHub Actions (recommended)

**ASK** the user to add these repository secrets (Settings › Secrets and variables › Actions). Never
put their values in files.

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID_CERT_P12` | Developer ID Application certificate + private key exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | Password chosen when exporting the `.p12` |
| `APPLE_TEAM_ID` | Team ID (10 characters) |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_APP_PASSWORD` | App-specific password for that Apple ID |
| `OPENUPDATER_PRIVATE_KEY` | Private key from `openupdater-cli generate-keys` |

`.github/workflows/release.yml` (adjust `MyApp` and the scheme; it releases when a `v*` tag is pushed):

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-15
    env:
      APP: MyApp
    steps:
      - uses: actions/checkout@v4

      - name: Import Developer ID certificate
        env:
          P12: ${{ secrets.DEVELOPER_ID_CERT_P12 }}
          P12_PASSWORD: ${{ secrets.DEVELOPER_ID_CERT_PASSWORD }}
        run: |
          KEYCHAIN_PASSWORD=$(uuidgen)
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security set-keychain-settings -lut 21600 build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          echo "$P12" | base64 --decode > cert.p12
          security import cert.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain
          security list-keychains -d user -s build.keychain $(security list-keychains -d user | tr -d '"')
          rm cert.p12

      - name: Archive and export
        env:
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcodebuild -scheme "$APP" -configuration Release -archivePath "build/$APP.xcarchive" \
            DEVELOPMENT_TEAM="$TEAM_ID" archive
          xcodebuild -exportArchive -archivePath "build/$APP.xcarchive" \
            -exportPath build/export -exportOptionsPlist ExportOptions.plist

      - name: Check version matches tag
        run: |
          PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "build/export/$APP.app/Contents/Info.plist")
          test "$PLIST_VERSION" = "${GITHUB_REF_NAME#v}" || { echo "Tag $GITHUB_REF_NAME != app version $PLIST_VERSION"; exit 1; }

      - name: Notarize and staple
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          ditto -c -k --keepParent "build/export/$APP.app" build/notarize.zip
          xcrun notarytool submit build/notarize.zip --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" --team-id "$TEAM_ID" --wait
          xcrun stapler staple "build/export/$APP.app"

      - name: Zip and sign update
        env:
          OPENUPDATER_PRIVATE_KEY: ${{ secrets.OPENUPDATER_PRIVATE_KEY }}
        run: |
          ditto -c -k --sequesterRsrc --keepParent "build/export/$APP.app" "build/$APP.zip"
          git clone --depth 1 -b dev https://github.com/Im-Fran/openupdater /tmp/openupdater
          swift run --package-path /tmp/openupdater openupdater-cli sign "build/$APP.zip"

      - name: Publish release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          PRERELEASE=""
          [[ "$GITHUB_REF_NAME" == *-* ]] && PRERELEASE="--prerelease"
          gh release create "$GITHUB_REF_NAME" "build/$APP.zip" "build/$APP.zip.sig" \
            --title "$GITHUB_REF_NAME" --generate-notes $PRERELEASE
```

If the project already has a release workflow, merge these steps into it instead of adding a second
one. To release: bump `CFBundleShortVersionString` (and `CFBundleVersion`), commit, then
`git tag v1.2.0 && git push origin v1.2.0`.

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
- Don't ship `.dmg` or `.pkg` assets, or more than one `.zip` per release. Use exactly one `.zip` with the `.app` at its root.
- Don't modify the zip after signing it with `openupdater-cli sign`, and don't sign the pre-notarization zip.
- Don't change the bundle ID or the Team ID between releases.
- Don't publish a tag that differs from `CFBundleShortVersionString`.
- Don't change the `OpenUpdater.*` keys in `UserDefaults`; they hold the user's preferences.
