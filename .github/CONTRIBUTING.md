# Contributing to OpenUpdater

Thanks for your interest! Bug reports, fixes and improvements are all welcome.

## Getting started

Requirements: macOS 14+ and Xcode 16+ (Swift 6 tools).

```bash
git clone https://github.com/Im-Fran/openupdater.git
cd openupdater
swift build
swift test
```

## Project layout

```
Sources/OpenUpdater/       Updater (state + scheduling), GitHub.swift (API + versions),
                           Installer.swift (download, verification, install), Views.swift (SwiftUI)
Sources/OpenUpdater/Resources/Localizable.xcstrings   UI strings (en + es-419)
Sources/openupdater-cli/   key generation and zip signing
Tests/OpenUpdaterTests/    Swift Testing suite
```

## Guidelines

- **Keep it dependency-free.** Only Apple frameworks.
- **Security first.** Never weaken the Ed25519 or code-signature checks. Changes to `Installer.swift` need a clear explanation in the PR.
- **Localize every UI string.** Add the English key and its `es-419` translation to `Localizable.xcstrings`, and use `bundle: .module`.
- **Test logic changes.** Version comparison, scheduling and signature code must stay covered by `swift test`.
- **Update the docs.** If you change the public API or the release flow, update `README.md`, `README.es.md` and `AGENT_SETUP.md`.

## Workflow

1. Open an issue first for larger changes, so we can agree on the approach.
2. Fork and create a branch: `feat/<short-description>` or `fix/<short-description>`.
3. Commit using [Conventional Commits](https://www.conventionalcommits.org), e.g. `fix: relaunch app after failed swap`.
4. Push and open a PR. CI must be green.

## Code of Conduct

By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
