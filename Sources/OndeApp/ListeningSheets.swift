import SwiftUI
import AppKit
import OndeCore

struct ListeningSheetView: View {
    @EnvironmentObject var model: AppModel
    let sheet: ListeningSheet
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(sheet.title).font(.system(size: 24, design: .serif))
                Spacer()
                Button("Done") { model.sheet = nil }.keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered).accessibilityLabel("Close \(sheet.title)")
            }.padding(24)
            Divider().overlay(Theme.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch sheet {
                    case .settings: SettingsView()
                    case .sound: SoundControlsView()
                    case .personal: PersonalAudioView()
                    case .history: HistoryView()
                    case .cli: CLIGuideView()
                    case .credits: CreditsView()
                    case .updates: UpdatesView(updates: model.updates)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
        }.frame(width: 800, height: 660).background(Theme.background).foregroundStyle(Theme.ink).preferredColorScheme(.dark)
    }
}
struct DefaultMusicSettings: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 17) {
                Text("Your starting music").font(.system(size: 22, design: .serif))
                Text("Clicking a mode starts this choice. Trying another track does not replace your default.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                ForEach(SessionMode.allCases) { mode in
                    HStack(spacing: 14) {
                        Image(systemName: mode.symbol).foregroundStyle(Theme.accent(mode)).frame(width: 23)
                        Text(mode.title).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("\(mode.title) default", selection: Binding(get: { model.defaultMusicID(for: mode) }, set: { id in
                            do { try model.setDefaultMusic(id, for: mode) } catch { model.fail(error) }
                        })) {
                            ForEach(MusicCatalog.profiles(for: mode)) { profile in Text(profile.title).tag(profile.id) }
                        }.labelsHidden().frame(width: 230).accessibilityLabel("\(mode.title) default")
                    }
                }
                Text("Relax and Meditation share the same music. Their defaults are independent.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
    }
}
struct PersonalAudioView: View {
    @EnvironmentObject var model: AppModel
    @State private var name = ""
    @State private var deleteID: String?
    @State private var deleteMixID: String?
    var body: some View {
        Text("Optional tools. Your existing mixes and imports stay private on this Mac.")
            .font(.system(size: 12)).foregroundStyle(Theme.muted)
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                Text("Saved mixes").font(.system(size: 21, design: .serif))
                HStack {
                    TextField("Name this mix", text: $name).textFieldStyle(.roundedBorder)
                    Button("Save current mix") {
                        do { try model.saveMix(name: name); name = "" } catch { model.fail(error) }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.store.mixes) { mix in
                    HStack {
                        Text(mix.name).font(.system(size: 13))
                        Spacer()
                        Text(mix.mode.title).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        Button("Play") { do { try model.loadMix(mix.id) } catch { model.fail(error) } }
                            .accessibilityLabel("Play saved mix \(mix.name), \(mix.mode.title)")
                            .accessibilityIdentifier("play-mix-\(mix.id)")
                        Button { deleteMixID = mix.id } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).help("Delete saved mix")
                            .accessibilityLabel("Delete saved mix \(mix.name)")
                            .accessibilityIdentifier("delete-mix-\(mix.id)")
                    }
                }
                if model.store.mixes.isEmpty { Text("No saved mixes yet.").font(.system(size: 11)).foregroundStyle(Theme.muted) }
            }
        }
        .confirmationDialog("Delete this saved mix?", isPresented: Binding(get: { deleteMixID != nil }, set: { if !$0 { deleteMixID = nil } }), titleVisibility: .visible, presenting: deleteMixID) { id in
            Button("Delete saved mix", role: .destructive) {
                removeMix(id)
                deleteMixID = nil
            }
            Button("Cancel", role: .cancel) { deleteMixID = nil }
        } message: { _ in
            Text("Only this saved mix is removed. Current playback, imported audio files and session history are kept.")
        }
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Personal audio").font(.system(size: 21, design: .serif))
                    Spacer()
                    Button("Import audio…") { model.importFromPanel() }
                }
                if model.sounds.filter(\.imported).isEmpty {
                    Text("Import a local audio file. It is never included in published builds.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                ForEach(model.sounds.filter(\.imported)) { sound in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sound.title).font(.system(size: 13)); Text(sound.displaySubtitle).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Play") { play(sound) }
                            .accessibilityLabel("Play imported audio \(sound.title)")
                            .accessibilityIdentifier("play-import-\(sound.id)")
                        Button { deleteID = sound.id } label: { Image(systemName: "trash") }
                            .help("Delete only the imported copy").accessibilityLabel("Delete local copy of \(sound.title)")
                    }
                }
            }
        }
        DisclosureGroup("Recorded sounds from earlier versions") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Preserved for existing mixes. The main screen uses continuously generated music.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                ForEach(model.sounds.filter { !$0.imported && ["Music", "Composition"].contains($0.kind) }) { sound in
                    HStack {
                        Text(sound.title).font(.system(size: 12))
                        Spacer()
                        Button("Play") { play(sound) }
                            .accessibilityLabel("Play recorded sound \(sound.title)")
                            .accessibilityIdentifier("play-recorded-\(sound.id)")
                    }
                }
            }.padding(.top, 12)
        }.font(.system(size: 12))
        if !model.activeSounds.filter({ $0.id != "living" }).isEmpty {
            Text("Active recorded layers").font(.system(size: 16, design: .serif))
            ForEach(model.activeSounds.filter { $0.id != "living" }) { sound in MixerRow(sound: sound) }
        }
        Text("The command-line interface still supports all existing mix and import commands.").font(.system(size: 10)).foregroundStyle(Theme.muted)
            .confirmationDialog("Delete this local copy? Your original file is not changed.", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("Delete local copy", role: .destructive) {
                    if let id = deleteID { do { try model.removeImport(id) } catch { model.fail(error) } }
                    deleteID = nil
                }
            }
    }
    private func removeMix(_ id: String) {
        let reply = model.handle(["command": "mix.delete", "id": id])
        if reply["ok"] as? Bool == true { model.notify("Saved mix deleted.") }
        else {
            let error = reply["error"] as? [String: Any]
            model.fail(OndeError(error?["code"] as? String ?? "operation_failed", error?["message"] as? String ?? "The saved mix could not be deleted."))
        }
    }
    private func play(_ sound: Sound) {
        let reply = model.handle(["command":"solo", "id":sound.id])
        if reply["ok"] as? Bool == true { model.play() }
    }
}