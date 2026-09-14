import SwiftUI
import OndeCore

struct UpdatesView: View {
    @ObservedObject var updates: UpdateManager
    var body: some View {
        PageHeader(eyebrow: "Onde · logiciel libre", title: "Toujours à jour. À votre choix.", subtitle: "Les versions sont compilées depuis main et publiées sur GitHub. Rien ne s’installe sans vous.")
        Panel {
            VStack(alignment: .leading, spacing: 21) {
                HStack(spacing: 16) {
                    Image(systemName: updates.available ? "arrow.down.circle.fill" : "checkmark.seal")
                        .font(.system(size: 32, weight: .light)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(updates.available ? "Une nouvelle version vous attend." : "Votre version : \(AppBuild.version)")
                            .font(.system(size: 24, design: .serif))
                        Text(updates.candidate?.title ?? "Vérifiez les publications disponibles.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if updates.checking || updates.downloading { ProgressView().controlSize(.small) }
                }
                HStack(spacing: 12) {
                    PillButton(title: updates.checking ? "Vérification…" : "Rechercher une mise à jour", symbol: "arrow.clockwise") { updates.check() }
                        .disabled(updates.checking || updates.downloading)
                    if updates.candidate != nil {
                        PillButton(title: updates.downloading ? "Téléchargement…" : "Télécharger la mise à jour", symbol: "arrow.down", primary: true) { updates.download() }
                            .disabled(updates.downloading || updates.checking)
                    }
                }
                if let error = updates.error { Text(error).font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled) }
                if let path = updates.downloadedPath {
                    Label("Archive téléchargée et vérifiée par SHA-256.", systemImage: "checkmark.shield.fill").foregroundStyle(Theme.accent).font(.system(size: 12))
                    Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled)
                    PillButton(title: "Afficher dans Finder", symbol: "folder") { updates.reveal() }
                }
                if let date = updates.lastChecked {
                    Text("Dernière vérification : \(date.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        Panel {
            VStack(alignment: .leading, spacing: 19) {
                Toggle(isOn: $updates.automatic) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Détecter les nouvelles versions").font(.system(size: 13, weight: .medium))
                        Text("Au lancement, au retour dans l’app et toutes les cinq minutes. Aucun téléchargement automatique.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }.toggleStyle(.switch).tint(Theme.accent)
                Text("Seule l’API publique de GitHub est contactée pour cette vérification. Vos écoutes, réglages et imports ne sont pas envoyés.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                Divider()
                Text("Installer la nouvelle version").font(.system(size: 20, design: .serif))
                Text("Décompressez l’archive, quittez Onde, puis remplacez Onde.app dans votre dossier Applications. Vos ambiances et réglages restent dans votre bibliothèque personnelle.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Text("Community Build : signature locale, sans notarisation Apple. La vérification SHA-256 contrôle l’intégrité du téléchargement ; elle ne remplace pas une signature Developer ID.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                Link("Voir le code et les versions sur GitHub", destination: URL(string: "https://github.com/\(AppBuild.repository)")!)
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
                Text("Nouvelle version disponible").font(.system(size: 12, weight: .medium))
                Spacer()
                Button(updates.downloading ? "Téléchargement…" : "Télécharger") { updates.download(); model.page = "updates" }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent).font(.system(size: 12, weight: .semibold)).disabled(updates.downloading)
            }.padding(.horizontal, 30).padding(.vertical, 12).background(Theme.panel)
        }
    }
}
