import SwiftUI
import OndeCore

struct UpdatesView: View {
    @ObservedObject var updates: UpdateManager
    var body: some View {
        PageHeader(eyebrow: "Onde · open source", title: "Stay up to date. On your terms.", subtitle: "Builds are published from main on GitHub. Nothing installs without you.")
        Panel {
            VStack(alignment: .leading, spacing: 21) {
                HStack(spacing: 16) {
                    Image(systemName: updates.available ? "arrow.down.circle.fill" : "checkmark.seal")
                        .font(.system(size: 32, weight: .light)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(updates.available ? "An update is ready." : "Your version: \(AppBuild.version)")
                            .font(.system(size: 24, design: .serif))
                        Text(updates.candidate?.title ?? "Check for available releases.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if updates.checking || updates.downloading { ProgressView().controlSize(.small) }
                }
                HStack(spacing: 12) {
                    PillButton(title: updates.checking ? "Checking…" : "Check for updates", symbol: "arrow.clockwise") { updates.check() }
                        .disabled(updates.checking || updates.downloading)
                    if updates.candidate != nil {
                        PillButton(title: updates.downloading ? "Downloading…" : "Download update", symbol: "arrow.down", primary: true) { updates.download() }
                            .disabled(updates.downloading || updates.checking)
                    }
                }
                if let error = updates.error { Text(error).font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled) }
                if let path = updates.downloadedPath {
                    Label("Download verified with SHA-256.", systemImage: "checkmark.shield.fill").foregroundStyle(Theme.accent).font(.system(size: 12))
                    Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled)
                    PillButton(title: "Show in Finder", symbol: "folder") { updates.reveal() }
                }
                if let date = updates.lastChecked {
                    Text("Last checked: \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "en"))))").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        Panel {
            VStack(alignment: .leading, spacing: 19) {
                Toggle(isOn: $updates.automatic) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Automatically check for updates").font(.system(size: 13, weight: .medium))
                        Text("At launch, when returning to the app and every five minutes. Downloads remain manual.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }.toggleStyle(.switch).tint(Theme.accent)
                Text("Checks contact only GitHub's public API. Listening history, settings and imports are not sent.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                Divider()
                Text("Install the new version").font(.system(size: 20, design: .serif))
                Text("Unzip the download, quit Onde, then replace Onde.app in your Applications folder. Your mixes and settings stay in your personal library.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Text("Community build: ad-hoc signed, not notarized by Apple. SHA-256 verifies download integrity; it does not replace a Developer ID signature.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                Link("View source and releases on GitHub", destination: URL(string: "https://github.com/\(AppBuild.repository)")!)
                    .font(.system(size: 12)).tint(Theme.accent)
                Text("Build \(AppBuild.number) · \(AppBuild.commit.prefix(8))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct UpdateBanner: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var updates: UpdateManager
    var body: some View {
        if updates.available {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle").foregroundStyle(Theme.accent)
                Text("A new version is available").font(.system(size: 12, weight: .medium))
                Spacer()
                Button(updates.downloading ? "Downloading…" : "Download") { updates.download(); model.page = "updates" }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent).font(.system(size: 12, weight: .semibold)).disabled(updates.downloading)
            }.padding(.horizontal, 30).padding(.vertical, 12).background(Theme.panel)
        }
    }
}
