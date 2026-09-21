import SwiftUI
import OndeCore

struct UpdatesView: View {
    @ObservedObject var updates: UpdateManager
    @ObservedObject private var installation = UpdateInstallationController.shared

    private var title: String {
        if installation.busy { return "Installing your update…" }
        if updates.downloadedPath != nil { return "Ready to install." }
        if updates.available { return "An update is ready." }
        return "Your version: \(AppBuild.version)"
    }
    private var progressTitle: String {
        if updates.verifying { return "Verifying SHA-256…" }
        if let progress = updates.downloadProgress { return "Downloading \(Int((progress * 100).rounded()))%" }
        return "Preparing secure download…"
    }
    private var progressDetail: String {
        let expected = updates.expectedDownloadBytes
        guard expected > 0 else { return "Waiting for GitHub…" }
        let total = ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)
        guard updates.downloadedBytes > 0 else { return total }
        return "\(ByteCountFormatter.string(fromByteCount: updates.downloadedBytes, countStyle: .file)) of \(total)"
    }

    var body: some View {
        PageHeader(eyebrow: "Onde · open source", title: "Stay up to date. On your terms.", subtitle: "Download, verify, then install and relaunch. Nothing installs without your approval.")
        Panel {
            VStack(alignment: .leading, spacing: 21) {
                HStack(spacing: 16) {
                    Image(systemName: updates.downloadedPath != nil ? "checkmark.circle.fill" : updates.available ? "arrow.down.circle.fill" : "checkmark.seal")
                        .font(.system(size: 32, weight: .light)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title).font(.system(size: 24, design: .serif)).accessibilityIdentifier("updates.title")
                        Text(updates.candidate?.title ?? "Check for available releases.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if updates.checking || installation.busy { ProgressView().controlSize(.small) }
                }

                if installation.busy {
                    Label(installation.status ?? "Preparing the update…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12)).foregroundStyle(Theme.accent)
                } else if let path = updates.downloadedPath, let update = updates.candidate, updates.available {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The download is complete. Install it to use the new version.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        HStack(spacing: 12) {
                            PillButton(title: "Install and Relaunch", symbol: "arrow.triangle.2.circlepath", primary: true) {
                                installation.install(archive: URL(fileURLWithPath: path), update: update)
                            }.disabled(updates.checking).accessibilityIdentifier("updates.install")
                            PillButton(title: "Show in Finder", symbol: "folder") { updates.reveal() }
                        }
                        if installation.error != nil {
                            Button("Download again") { updates.downloadAgain() }
                                .buttonStyle(.plain).foregroundStyle(Theme.accent).disabled(updates.checking)
                        }
                        Text("Playback will stop during the restart. Your settings, soundscapes, history and imports stay in your library.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3)
                    }
                } else {
                    HStack(spacing: 12) {
                        PillButton(title: updates.checking ? "Checking…" : "Check for updates", symbol: "arrow.clockwise") { updates.check() }
                            .disabled(updates.checking || updates.downloading)
                        if updates.available {
                            if updates.downloading {
                                PillButton(title: updates.verifying ? "Verifying…" : "Downloading…", symbol: updates.verifying ? "checkmark.shield" : "arrow.down", primary: true) {}.disabled(true)
                                if !updates.verifying { PillButton(title: "Cancel", symbol: "xmark") { updates.cancelDownload() } }
                            } else {
                                PillButton(title: "Download update", symbol: "arrow.down", primary: true) { updates.download() }
                                    .disabled(updates.checking).accessibilityIdentifier("updates.download")
                            }
                        }
                    }
                }

                if updates.downloading {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(progressTitle).font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(progressDetail).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
                        }
                        if updates.verifying { ProgressView().controlSize(.small) }
                        else if let progress = updates.downloadProgress { ProgressView(value: progress).tint(Theme.accent) }
                        else { ProgressView() }
                        Text(updates.verifying ? "Checking the complete archive. Install and Relaunch will appear when it is ready." : "Keep Onde open. When the download finishes, choose Install and Relaunch.")
                            .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                    }.padding(14).background(Theme.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                }

                if let message = installation.error ?? updates.error {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled)
                        .accessibilityIdentifier("updates.error")
                } else if !installation.busy, let status = installation.status {
                    Label(status, systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.accent)
                }
                if updates.downloadedPath != nil {
                    Label("Download verified. The application is checked again before installation.", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(Theme.accent).font(.system(size: 11))
                }
                if updates.available, !installation.busy, updates.downloadedPath == nil {
                    Button { updates.openDownloadInBrowser() } label: {
                        Label("Download in browser instead", systemImage: "safari").font(.system(size: 11, weight: .medium))
                    }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                }
                Text("Currently installed: \(AppBuild.version) · \(AppBuild.number)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                if let date = updates.lastChecked {
                    Text("Last checked: \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "en"))))")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        Panel {
            VStack(alignment: .leading, spacing: 19) {
                Toggle(isOn: $updates.automatic) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Automatically check for updates").font(.system(size: 13, weight: .medium))
                        Text("At launch, when returning to the app and every five minutes. Downloads and installation require your approval.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }.toggleStyle(.switch).tint(Theme.accent).disabled(installation.busy)
                Text("Checks contact only GitHub's public API. Listening history, settings and imports are not sent.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                DisclosureGroup("Manual installation and build details") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("For an older download-only version: unzip the archive, quit Onde and replace Onde.app in Applications once. Future updates can be installed from this screen.")
                        Text("Community build: ad-hoc signed, not notarized by Apple. SHA-256 and the official GitHub release protect download integrity; they do not replace a Developer ID signature. macOS security settings are never disabled.")
                        Link("View source and releases on GitHub", destination: URL(string: "https://github.com/\(AppBuild.repository)")!)
                    }.font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).padding(.top, 10)
                }.font(.system(size: 12)).tint(Theme.accent)
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
                Text(updates.downloadedPath != nil ? "Your update is ready to install" : "A new version is available").font(.system(size: 12, weight: .medium))
                Spacer()
                Button("View update") { model.page = "updates" }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent).font(.system(size: 12, weight: .semibold))
            }.padding(.horizontal, 30).padding(.vertical, 12).background(Theme.panel)
        }
    }
}
