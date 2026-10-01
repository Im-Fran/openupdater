import SwiftUI

private func t(_ key: LocalizedStringKey) -> Text { Text(key, bundle: .module) }

struct UpdateView: View {
    let updater: Updater

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(width: 520)
    }

    @ViewBuilder private var content: some View {
        let name = updater.appName
        switch updater.state {
        case .idle, .checking:
            t("Checking for updates…").font(.headline)
            ProgressView().progressViewStyle(.linear)

        case .upToDate:
            t("You're up to date!").font(.headline)
            t("\(name) \(updater.currentVersion) is the latest version.").foregroundStyle(.secondary)
            closeButton

        case .available(let release):
            t("A new version of \(name) is available!").font(.headline)
            t("\(name) \(release.version) is available — you have \(updater.currentVersion).")
                .foregroundStyle(.secondary)
            if let notes = release.body, !notes.isEmpty {
                ScrollView {
                    Text(markdown(notes))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 200)
                .background(.background.secondary, in: .rect(cornerRadius: 6))
            }
            HStack {
                Button { updater.dismiss() } label: { t("Later") }
                Spacer()
                Button { updater.install(now: false) } label: { t("Install on Next Launch") }
                Button { updater.install(now: true) } label: { t("Install and Relaunch") }
                    .keyboardShortcut(.defaultAction)
            }

        case .downloading(let progress):
            t("Downloading update…").font(.headline)
            ProgressView(value: progress)

        case .scheduled:
            t("Update ready").font(.headline)
            t("The update will be installed the next time you open \(name).").foregroundStyle(.secondary)
            closeButton

        case .error(let message):
            t("Update failed").font(.headline)
            Text(message).foregroundStyle(.secondary)
            closeButton
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { updater.dismiss() } label: { t("OK") }.keyboardShortcut(.defaultAction)
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

/// Drop into your app's `Settings` scene.
public struct UpdaterSettingsView: View {
    @Bindable var updater: Updater

    public init(updater: Updater) { self.updater = updater }

    public var body: some View {
        Form {
            Toggle(isOn: $updater.automaticChecks) { t("Automatically check for updates") }
            Picker(selection: $updater.frequency) {
                t("Daily").tag(CheckFrequency.daily)
                t("Weekly").tag(CheckFrequency.weekly)
                t("Monthly").tag(CheckFrequency.monthly)
            } label: { t("Check frequency") }
                .disabled(!updater.automaticChecks)
            Toggle(isOn: $updater.includePrereleases) { t("Include pre-release versions") }
            HStack {
                Button { updater.checkNow() } label: { t("Check Now") }
                Spacer()
                if let date = updater.lastCheck {
                    t("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
