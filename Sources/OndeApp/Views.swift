import SwiftUI
import AppKit
import OndeCore

struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Group {
            if model.quietView { QuietView() }
            else {
                HStack(spacing: 0) {
                    Sidebar().frame(width: 202)
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 25) {
                                switch model.page {
                                case "updates": UpdatesView(updates: model.updates)
                                case "endel": EndelSessionsView()
                                case "generative": GenerativeView()
                                case "library": LibraryView()
                                case "mixes": MixesView()
                                case "settings": SettingsView()
                                case "cli": CLIGuideView()
                                case "history": HistoryView()
                                case "credits": CreditsView()
                                default: StudioView()
                                }
                            }.padding(.horizontal, 32).padding(.top, 34).padding(.bottom, 26)
                        }
                        UpdateBanner(updates: model.updates)
                        PlayerBar()
                    }.background(Theme.background)
                }
            }
        }
        .frame(minWidth: 1060, minHeight: 730)
        .background(Theme.background).foregroundStyle(Theme.ink)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let text = model.toast {
                Label(text, systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.raised, in: Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 15, y: 5).padding(.top, 12)
                    .allowsHitTesting(false)
            }
        }
        .alert("Onde", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Fermer", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path").font(.system(size: 25, weight: .light)).foregroundStyle(Theme.accent)
                Text("onde").font(.system(size: 33, weight: .regular, design: .serif)).tracking(-1.8)
            }.padding(.horizontal, 25).padding(.top, 44)
            Text("Un espace pour soi.").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.leading, 26).padding(.top, 7)
            VStack(spacing: 5) {
                nav("studio", "Espace sonore", "circle.hexagongrid")
                nav("generative", "Paysages vivants", "waveform.path.ecg")
                nav("library", "Bibliothèque", "square.grid.2x2")
                nav("endel", "Endel · intégrales", "play.rectangle")
                nav("mixes", "Mes ambiances", "slider.horizontal.3")
                nav("history", "Mes sessions", "clock")
            }.padding(.horizontal, 13).padding(.top, 26)
            Spacer()
            VStack(alignment: .leading, spacing: 13) {
                Eyebrow(text: "Aujourd’hui")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(model.todaySeconds / 60))").font(.system(size: 31, weight: .light, design: .rounded)).monospacedDigit()
                    Text("min pour vous").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Rectangle().fill(Theme.line).frame(height: 1)
            }.padding(.horizontal, 26).padding(.bottom, 18)
            VStack(spacing: 4) {
                nav("cli", "Pour les agents", "terminal")
                nav("settings", "Réglages", "gearshape")
                nav("updates", "Mises à jour", "arrow.down.circle")
                nav("credits", "À propos & crédits", "info.circle")
            }.padding(.horizontal, 13)
            HStack(spacing: 6) {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text("LOCAL · LIBRE · SANS COMPTE").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.6).foregroundStyle(Theme.muted)
            }.padding(.horizontal, 23).padding(.top, 23).padding(.bottom, 24)
        }.background(Theme.sidebar)
    }
    func nav(_ id: String, _ title: String, _ symbol: String) -> some View {
        Button { model.page = id } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 14, weight: .regular)).frame(width: 18)
                Text(title).font(.system(size: 12, weight: model.page == id ? .semibold : .regular))
                Spacer(minLength: 0)
                if model.page == id { Circle().fill(Theme.accent).frame(width: 4, height: 4) }
            }.foregroundStyle(model.page == id ? Theme.ink : Theme.muted).padding(.horizontal, 13).padding(.vertical, 12)
                .background(model.page == id ? Theme.raised.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}
struct PageHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 29, weight: .regular, design: .serif)).tracking(-0.7)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted) }
        }
    }
}
struct StudioView: View {
    @EnvironmentObject var model: AppModel
    @State private var showSave = false
    @State private var mixName = ""
    var body: some View {
        HStack(alignment: .top) {
            PageHeader(eyebrow: "Votre espace sonore", title: "Moins de bruit. Plus d’espace.", subtitle: "Choisissez une intention, puis trouvez votre équilibre.")
            Spacer()
            HStack(spacing: 6) { Circle().fill(Theme.accent).frame(width: 5, height: 5); Text("Sons locaux · hors ligne").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                .padding(.horizontal, 12).padding(.vertical, 8).overlay(Capsule().stroke(Theme.line)).padding(.top, 4)
        }
        HStack(spacing: 12) { ForEach(SessionMode.allCases) { mode in ModeButton(mode: mode) } }
        GeneratorStudioStrip()
        HStack(alignment: .top, spacing: 18) {
            hero.frame(maxWidth: .infinity)
            SessionPanel().frame(width: 276)
        }
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Votre paysage sonore").font(.system(size: 18, weight: .regular, design: .serif))
                    Text("Chaque couche a sa place. Ajustez la vôtre.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { showSave = true } label: { Label("Enregistrer", systemImage: "bookmark").font(.system(size: 11)).foregroundStyle(Theme.muted) }.buttonStyle(.plain)
                PillButton(title: "Ajouter un son", symbol: "plus") { model.page = "library" }
            }
            if model.activeSounds.isEmpty {
                HStack { Image(systemName: "speaker.slash"); Text("Le silence est aussi un paysage."); Spacer(); Button("Explorer les sons") { model.page = "library" } }
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).padding(24).background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(model.activeSounds) { sound in MixerRow(sound: sound) }
                }
            }
        }
        .sheet(isPresented: $showSave) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Garder cette ambiance").font(.system(size: 24, design: .serif))
                Text("Les sons, leurs volumes et le mode sont enregistrés ensemble.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                TextField("Nom de l’ambiance", text: $mixName).textFieldStyle(.roundedBorder)
                HStack { Button("Annuler") { showSave = false }; Spacer(); Button("Enregistrer") { do { try model.saveMix(name: mixName); showSave = false; mixName = "" } catch { model.fail(error) } }.keyboardShortcut(.defaultAction).disabled(mixName.trimmingCharacters(in: .whitespaces).isEmpty) }
            }.padding(30).frame(width: 440).background(Theme.background)
        }
    }
    var hero: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Theme.panel, Theme.accent(model.mode).opacity(0.085)], startPoint: .topLeading, endPoint: .bottomTrailing)
            OrbitalArt(mode: model.mode, animated: model.playing && !model.store.preferences.reducedMotion).frame(width: 270, height: 270).frame(maxWidth: .infinity, alignment: .trailing).offset(x: 48, y: 38).opacity(0.95)
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 7) {
                    Image(systemName: model.mode.symbol).font(.system(size: 11))
                    Eyebrow(text: model.mode == .focus ? "Une chose à la fois" : model.mode == .relax ? "Le droit de ralentir" : "Revenir à l’essentiel", color: Theme.accent(model.mode))
                }.foregroundStyle(Theme.accent(model.mode))
                Text(headline).font(.system(size: 35, weight: .regular, design: .serif)).tracking(-0.7).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4).frame(maxWidth: 220, alignment: .leading)
                Spacer(minLength: 0)
                Button { model.quietView = true } label: {
                    HStack(spacing: 7) { Image(systemName: "arrow.up.left.and.arrow.down.right"); Text("Passer en vue calme"); Image(systemName: "arrow.up.right").font(.system(size: 8)) }.font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.accent(model.mode))
                }.buttonStyle(.plain).help("Masquer l’interface · ⇧⌘F")
            }.padding(25)
        }.frame(height: 283).clipShape(RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))
    }
    var headline: String { switch model.mode { case .focus: return "Faites de la place.\nÀ ce qui compte."; case .relax: return "Rien à réussir.\nJuste ralentir."; case .meditation: return "Nulle part où aller.\nJuste être ici." } }
    var subtitle: String { switch model.mode { case .focus: return "Des textures douces, un esprit libre.\nEntrez dans votre rythme."; case .relax: return "Laissez la journée se déposer.\nLe reste peut attendre."; case .meditation: return "Des repères discrets, puis aucun rappel.\nVotre pratique reste ouverte." } }
}
struct ModeButton: View {
    @EnvironmentObject var model: AppModel
    var mode: SessionMode
    var selected: Bool { model.mode == mode }
    var body: some View {
        Button { model.startMode(mode) } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol).font(.system(size: 18, weight: .light)).frame(width: 23)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title).font(.system(size: 13, weight: .semibold))
                    Text(mode == .focus ? "Entrer dans le rythme" : mode == .relax ? "Décompresser" : "Prendre le temps").font(.system(size: 10)).opacity(selected ? 0.7 : 0.65)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "arrow.up.right").font(.system(size: selected ? 15 : 11)).opacity(selected ? 1 : 0.6)
            }.padding(.horizontal, 17).padding(.vertical, 16).frame(maxWidth: .infinity)
                .foregroundStyle(selected ? Theme.sidebar : Theme.ink)
                .background(selected ? Theme.accent(mode) : Theme.panel, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? Color.clear : Theme.line))
        }.buttonStyle(.plain).help("Démarrer \(mode.title)").accessibilityLabel("Démarrer \(mode.title)")
    }
}
struct SessionPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: model.mode == .meditation ? "Votre pratique" : "Votre session", color: Color(hex: 0x58634E))
                Spacer()
                Circle().fill(model.playing ? Color(hex: 0x718D54) : .gray.opacity(0.4)).frame(width: 6, height: 6)
            }
            Text(clockText(model.elapsed)).font(.system(size: 49, weight: .light, design: .rounded)).monospacedDigit().tracking(-2).padding(.top, 19)
            Text(model.playing ? "Le temps est à vous." : model.elapsed > 0 ? "En pause. Rien ne presse." : "Quand vous serez prêt.")
                .font(.system(size: 11)).foregroundStyle(Color(hex: 0x66705E)).padding(.top, 4)
            HStack(spacing: 9) {
                Button { model.togglePlayback() } label: {
                    HStack(spacing: 8) { Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 10)); Text(model.playing ? "Pause" : model.elapsed > 0 ? "Reprendre" : "Commencer").font(.system(size: 12, weight: .semibold)) }
                        .frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(Theme.ink).background(Theme.sidebar, in: Capsule())
                }.buttonStyle(.plain).accessibilityLabel(model.playing ? "Mettre en pause" : "Commencer la session")
                Button { model.stop() } label: { Image(systemName: "stop.fill").font(.system(size: 10)).frame(width: 38, height: 38).background(.black.opacity(0.06), in: Circle()) }.buttonStyle(.plain).help("Terminer et remettre à zéro")
            }.padding(.top, 19)
            Spacer(minLength: 13)
            if model.mode == .meditation {
                if model.store.preferences.chimesEnabled && !model.store.preferences.markers.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "bell").font(.system(size: 10))
                        ForEach(Array(model.store.preferences.markers.prefix(4)), id: \.self) { m in
                            Text(markerLabel(m)).font(.system(size: 9, weight: .medium, design: .monospaced)).padding(.horizontal, 7).padding(.vertical, 4)
                                .background(.black.opacity(model.clock.fired.contains(m) ? 0.12 : 0.045), in: Capsule())
                        }
                        if model.store.preferences.markers.count > 4 { Text("…").font(.system(size: 10)) }
                        Spacer(minLength: 0)
                        Button { model.page = "settings" } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 10)) }.buttonStyle(.plain).help("Configurer les repères")
                    }.foregroundStyle(Color(hex: 0x59634F))
                    Text(model.nextMarker == nil && model.elapsed > 0 ? "Aucun autre rappel. Le temps continue." : "Après le dernier repère : aucun rappel.")
                        .font(.system(size: 9)).foregroundStyle(Color(hex: 0x66705E)).padding(.top, 8)
                } else {
                    Label("Sans carillon. Le temps continue.", systemImage: "bell.slash").font(.system(size: 10)).foregroundStyle(Color(hex: 0x66705E))
                }
            } else {
                HStack(spacing: 6) { Image(systemName: "infinity").font(.system(size: 13)); Text("Sans limite. Sans compte à rebours.").font(.system(size: 9)) }.foregroundStyle(Color(hex: 0x66705E))
                Text("Vos repères sonores sont réservés à la méditation.").font(.system(size: 9)).foregroundStyle(Color(hex: 0x66705E)).padding(.top, 8)
            }
        }.padding(23).frame(height: 283).background(Color(hex: 0xE8ECDf), in: RoundedRectangle(cornerRadius: 22)).foregroundStyle(Theme.sidebar)
    }
    func markerLabel(_ seconds: Double) -> String { seconds.truncatingRemainder(dividingBy: 60) == 0 ? "\(Int(seconds / 60)) min" : "\(Int(seconds)) s" }
}
struct MixerRow: View {
    @EnvironmentObject var model: AppModel
    var sound: Sound
    var volume: Double { model.store.layers[sound.id]?.volume ?? 0.5 }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sound.symbol).font(.system(size: 17, weight: .light)).foregroundStyle(Theme.accent).frame(width: 39, height: 43).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(sound.title).font(.system(size: 11, weight: .medium)).lineLimit(1); Spacer(); Text("\(Int(volume * 100)) %").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted) }
                Slider(value: Binding(get: { volume }, set: { model.setSound(sound.id, volume: $0) }), in: 0...1).tint(Theme.accent).controlSize(.mini).accessibilityLabel("Volume de \(sound.title)")
            }
            Button { model.setSound(sound.id, enabled: false) } label: { Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(Theme.muted).frame(width: 18, height: 24) }.buttonStyle(.plain).help("Désactiver \(sound.title)")
        }.padding(.horizontal, 15).padding(.vertical, 13).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}
struct PlayerBar: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 14) {
            Button { model.togglePlayback() } label: { Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 11)).foregroundStyle(Theme.sidebar).frame(width: 35, height: 35).background(Theme.accent(model.mode), in: Circle()) }.buttonStyle(.plain).accessibilityLabel(model.playing ? "Pause" : "Lecture")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.endel.selected.map { "Endel · " + $0.title } ?? (model.activeSounds.isEmpty ? "Le silence" : model.activeSounds.map(\.title).joined(separator: " + "))).font(.system(size: 11, weight: .medium)).lineLimit(1)
                HStack(spacing: 6) { Text(model.mode.title); Text("·"); Text(model.playing ? "En cours" : "En pause"); Text("·"); Text(clockText(model.elapsed)).monospacedDigit() }.font(.system(size: 9)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 20)
            Image(systemName: model.store.preferences.masterVolume == 0 ? "speaker.slash" : "speaker.wave.2").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { model.store.preferences.masterVolume }, set: model.setMaster), in: 0...1).tint(Theme.accent).controlSize(.small).frame(width: 115).accessibilityLabel("Volume général")
            Text("\(Int(model.store.preferences.masterVolume * 100))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted).frame(width: 23)
            Rectangle().fill(Theme.line).frame(width: 1, height: 22).padding(.horizontal, 3)
            Button { model.quietView = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12)).foregroundStyle(Theme.muted) }.buttonStyle(.plain).help("Vue calme")
        }.padding(.horizontal, 28).padding(.vertical, 17).background(Theme.sidebar.opacity(0.75)).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var filter = "Tous"
    @State private var deleteID: String?
    var filtered: [Sound] { model.sounds.filter { (filter == "Tous" || $0.kind == filter) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        HStack { PageHeader(eyebrow: "À écouter, à composer", title: "La matière de votre calme.", subtitle: "Activez plusieurs sons. Chaque couche se règle indépendamment."); Spacer(); PillButton(title: "Importer", symbol: "plus") { model.importFromPanel() } }
        HStack(spacing: 7) {
            ForEach(["Tous","Musique","Composition","Texture","Bruit","Personnel"], id: \.self) { value in
                Button { filter = value } label: { Text(value).font(.system(size: 11, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 8).foregroundStyle(filter == value ? Theme.sidebar : Theme.muted).background(filter == value ? Theme.accent : Theme.panel, in: Capsule()) }.buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 6) { Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted); TextField("Rechercher", text: $query).textFieldStyle(.plain) }.font(.system(size: 11)).padding(10).frame(width: 155).background(Theme.panel, in: Capsule())
        }
        if filtered.isEmpty {
            Panel { VStack(alignment: .leading, spacing: 12) { Text("Un peu d’espace libre.").font(.system(size: 24, design: .serif)); Text("Aucun son ici pour le moment. Importez un fichier personnel ou choisissez un autre filtre.").font(.system(size: 12)).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity, alignment: .leading) }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
            ForEach(filtered) { sound in
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        SoundArtwork(sound: sound)
                        Button { model.toggle(sound) } label: {
                            Image(systemName: model.store.layers[sound.id]?.enabled == true ? "checkmark" : "plus").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sidebar).frame(width: 30, height: 30).background(Theme.accent, in: Circle())
                        }.buttonStyle(.plain).padding(12).help(model.store.layers[sound.id]?.enabled == true ? "Désactiver" : "Ajouter au paysage")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(sound.title).font(.system(size: 13, weight: .semibold)).lineLimit(1); Spacer(minLength: 0); if sound.imported { Button { deleteID = sound.id } label: { Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(Theme.muted) }.buttonStyle(.plain) } }
                        Text(sound.subtitle).font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1)
                        HStack {
                            Text(sound.imported ? "LOCAL & PRIVÉ" : sound.license.uppercased()).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.7).foregroundStyle(Theme.muted)
                            Spacer()
                            Button { _ = model.handle(["command":"solo","id":sound.id]); model.play() } label: { Label("Écouter seul", systemImage: "play.fill").font(.system(size: 9)).foregroundStyle(Theme.accent) }.buttonStyle(.plain)
                        }.padding(.top, 6)
                    }.padding(16)
                }.background(Theme.panel).clipShape(RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(model.store.layers[sound.id]?.enabled == true ? Theme.accent.opacity(0.6) : Theme.line, lineWidth: 1))
            }
        }
        Text("Les textures de nature sont synthétisées, pas enregistrées. Les compositions de Kevin MacLeod sont créditées dans À propos. Vos imports ne sont jamais publiés avec l’app.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(4)
        .confirmationDialog("Supprimer la copie locale de ce son ? Le fichier original ne sera pas modifié.", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
            Button("Supprimer la copie", role: .destructive) { if let id = deleteID { do { try model.removeImport(id) } catch { model.fail(error) } }; deleteID = nil }
        }
    }
}
struct MixesView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow: "Vos repères", title: "Les ambiances à retrouver.", subtitle: "Enregistrez votre mélange depuis l’espace sonore, puis retrouvez-le en un clic.")
        if model.store.mixes.isEmpty {
            Panel { VStack(alignment: .leading, spacing: 18) { Image(systemName: "slider.horizontal.3").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Theme.accent); Text("Votre premier mélange vous attend.").font(.system(size: 25, design: .serif)); Text("Choisissez quelques sons, ajustez leurs volumes, puis cliquez sur Enregistrer.").font(.system(size: 12)).foregroundStyle(Theme.muted); PillButton(title: "Composer mon ambiance", symbol: "plus", primary: true) { model.page = "studio" } }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20) }
        }
        ForEach(model.store.mixes) { mix in
            Panel {
                HStack(spacing: 18) {
                    Image(systemName: mix.mode.symbol).font(.system(size: 23, weight: .light)).foregroundStyle(Theme.accent(mix.mode))
                    VStack(alignment: .leading, spacing: 7) { Text(mix.name).font(.system(size: 20, design: .serif)); Text("\(mix.mode.title) · \(mix.layers.values.filter(\.enabled).count) couches").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                    Spacer()
                    Button { model.store.mixes.removeAll { $0.id == mix.id }; model.persist() } label: { Image(systemName: "trash").foregroundStyle(Theme.muted) }.buttonStyle(.plain).help("Supprimer l’ambiance")
                    PillButton(title: "Écouter", symbol: "play.fill", primary: true) { do { try model.loadMix(mix.id) } catch { model.fail(error) } }
                }
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var markers = ""
    @State private var markerError = ""
    var body: some View {
        PageHeader(eyebrow: "À votre mesure", title: "Tout, à votre rythme.", subtitle: "Les réglages restent sur ce Mac et sont aussi accessibles depuis le CLI.")
        Panel {
            VStack(alignment: .leading, spacing: 21) {
                HStack { Image(systemName: "bell.badge").foregroundStyle(Theme.accent(.meditation)); Text("Les repères de méditation").font(.system(size: 21, design: .serif)); Spacer(); Toggle("Activer les carillons", isOn: Binding(get: { model.store.preferences.chimesEnabled }, set: { value in _ = model.handle(["command":"settings","key":"chimesEnabled","value":value]) })).labelsHidden().toggleStyle(.switch).tint(Theme.accent(.meditation)) }
                Text("Un son de verre doux et discret marque chaque repère. Après le dernier, aucun autre carillon ne joue et le chronomètre continue sans limite.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                VStack(alignment: .leading, spacing: 9) {
                    Text("Repères en minutes depuis le début de la session").font(.system(size: 11, weight: .medium))
                    HStack(spacing: 10) {
                        TextField("10, 20, 30", text: $markers).textFieldStyle(.plain).font(.system(size: 14, design: .monospaced)).padding(12).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 9)).onSubmit(saveMarkers)
                        PillButton(title: "Appliquer", symbol: "checkmark", primary: true, action: saveMarkers)
                        Button("Par défaut") { markers = "10, 20, 30"; saveMarkers() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    if !markerError.isEmpty { Text(markerError).font(.system(size: 11)).foregroundStyle(.orange) }
                    Text("Séparez les minutes par des virgules. Exemple : 5, 15, 25. Champ vide : aucun repère. Les repères déjà passés ne sont pas rejoués.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
                Divider().overlay(Theme.line)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) { Text("Discrétion du carillon").font(.system(size: 12, weight: .medium)); Text("Ce volume suit aussi le volume général.").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                    Spacer()
                    Slider(value: Binding(get: { model.store.preferences.chimeVolume }, set: model.setChime), in: 0...1).frame(width: 145).tint(Theme.accent(.meditation)).accessibilityLabel("Volume du carillon")
                    Text("\(Int(model.store.preferences.chimeVolume * 100)) %").font(.system(size: 11, design: .monospaced)).frame(width: 40)
                    PillButton(title: "Écouter", symbol: "bell") { model.previewChime() }
                }
            }
        }
        Panel {
            VStack(alignment: .leading, spacing: 23) {
                Text("Le son, sans rupture").font(.system(size: 21, design: .serif))
                HStack { VStack(alignment: .leading, spacing: 5) { Text("Fondu des transitions").font(.system(size: 12, weight: .medium)); Text("À la lecture et quand vous ajustez le paysage.").font(.system(size: 10)).foregroundStyle(Theme.muted) }; Spacer(); Slider(value: Binding(get: { model.store.preferences.fadeSeconds }, set: { model.store.preferences.fadeSeconds = $0; model.persist() }), in: 0...10, step: 0.5).frame(width: 180).tint(Theme.accent); Text(String(format: "%.1f s", model.store.preferences.fadeSeconds)).font(.system(size: 11, design: .monospaced)).frame(width: 45) }
                Toggle(isOn: Binding(get: { model.store.preferences.preventSleep }, set: { _ = model.handle(["command":"settings","key":"preventSleep","value":$0]) })) { VStack(alignment: .leading, spacing: 5) { Text("Garder la session active, écran éteint").font(.system(size: 12, weight: .medium)); Text("Empêche seulement la veille automatique du Mac. Fermer le capot ou forcer la veille met la session en pause.").font(.system(size: 10)).foregroundStyle(Theme.muted) } }.toggleStyle(.switch).tint(Theme.accent)
                Toggle(isOn: Binding(get: { model.store.preferences.reducedMotion }, set: { model.store.preferences.reducedMotion = $0; model.persist() })) { VStack(alignment: .leading, spacing: 5) { Text("Réduire les animations").font(.system(size: 12, weight: .medium)); Text("Le paysage visuel reste immobile.").font(.system(size: 10)).foregroundStyle(Theme.muted) } }.toggleStyle(.switch).tint(Theme.accent)
            }
        }
        .onAppear { updateMarkers() }
        .onChange(of: model.store.preferences.markers) { _, _ in updateMarkers() }
    }
    func updateMarkers() { markers = model.store.preferences.markers.map { String(format: "%g", $0 / 60) }.joined(separator: ", ") }
    func saveMarkers() {
        let trimmed = markers.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.isEmpty ? [] : trimmed.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap(Double.init)
        guard numbers.count == parts.count else { markerError = "Utilisez des nombres séparés par des virgules."; return }
        do { try model.setMarkers(numbers.map { $0 * 60 }); markerError = ""; model.notify("Repères mis à jour.") } catch { markerError = error.localizedDescription }
    }
}
struct QuietView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ZStack {
            Theme.sidebar
            OrbitalArt(mode: model.mode, animated: model.playing && !model.store.preferences.reducedMotion).frame(width: 650, height: 650).opacity(0.19)
            VStack(spacing: 20) {
                Eyebrow(text: model.mode.title, color: Theme.accent(model.mode).opacity(0.7))
                Text(clockText(model.elapsed)).font(.system(size: 96, weight: .ultraLight, design: .rounded)).monospacedDigit().tracking(-4).foregroundStyle(Theme.ink.opacity(0.8))
                Text(quietCaption).font(.system(size: 12)).foregroundStyle(Theme.muted.opacity(0.65))
                Button { model.togglePlayback() } label: { Image(systemName: model.playing ? "pause" : "play").font(.system(size: 19, weight: .ultraLight)).foregroundStyle(Theme.muted).frame(width: 50, height: 50).overlay(Circle().stroke(Theme.line)) }.buttonStyle(.plain).padding(.top, 20)
            }
            VStack { HStack { Spacer(); PillButton(title: "Quitter la vue calme", symbol: "arrow.down.right.and.arrow.up.left") { model.quietView = false } }; Spacer(); Text("Rien à atteindre.").font(.system(size: 15, weight: .regular, design: .serif)).foregroundStyle(Theme.muted.opacity(0.4)) }.padding(30)
        }
    }
    var quietCaption: String {
        guard model.mode == .meditation else { return "Un peu d’espace, simplement." }
        if let marker = model.nextMarker { return "Prochain repère à \(clockText(marker)). Puis le temps vous appartient." }
        return "Aucun autre rappel. Le temps continue."
    }
}
struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow: "Sans score, sans compétition", title: "Le temps que vous vous offrez.", subtitle: "Historique local des sessions terminées. Aucun objectif imposé.")
        if model.store.history.isEmpty { Panel { Text("Vos sessions apparaîtront ici une fois terminées.").font(.system(size: 13)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading) } }
        ForEach(model.store.history.prefix(50)) { session in
            HStack(spacing: 15) {
                Image(systemName: session.mode.symbol).foregroundStyle(Theme.accent(session.mode)).frame(width: 25)
                Text(session.mode.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(session.date, format: .dateTime.day().month().hour().minute()).font(.system(size: 11)).foregroundStyle(Theme.muted)
                Text(clockText(session.seconds)).font(.system(size: 15, design: .monospaced)).frame(width: 90, alignment: .trailing)
            }.padding(20).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
struct CLIGuideView: View {
    @EnvironmentObject var model: AppModel
    let examples = """
    onde focus --launch
    onde relax
    onde meditate
    onde pause
    onde play
    onde stop

    onde sounds
    onde sound rain on --volume 0.25
    onde sound aube off
    onde solo piano
    onde volume 0.4
    onde silence

    onde timer markers 10,20,30
    onde settings chimeVolume 0.2
    onde chime preview
    onde settings chimesEnabled false

    onde mix save \"Écriture du matin\"
    onde mix load \"Écriture du matin\"
    onde import \"/chemin/mon-son.wav\"
    onde status
    onde watch
    onde schema
    """
    var body: some View {
        PageHeader(eyebrow: "Agent-ready", title: "Le même contrôle. Sans cliquer.", subtitle: "Le CLI natif pilote directement l’app ouverte. Chaque réponse est un objet JSON.")
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                HStack { Text("Un seul état, deux interfaces.").font(.system(size: 22, design: .serif)); Spacer(); PillButton(title: "Copier", symbol: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(examples, forType: .string); model.notify("Commandes copiées.") } }
                Text("L’interface et le CLI utilisent le même moteur. Pas de port réseau : un socket UNIX privé, accessible seulement par votre utilisateur macOS.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                Text(examples).font(.system(size: 12, design: .monospaced)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 12))
                Text("Binaire installé : ~/.local/bin/onde\nLe flag --launch ouvre l’app si nécessaire. Sans ce flag, aucune ouverture implicite. onde schema décrit toutes les commandes pour un agent.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(5).textSelection(.enabled)
            }
        }
    }
}
struct CreditsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeader(eyebrow: "Onde · 1.2", title: "Le calme n’a pas besoin de compte.", subtitle: "Application native macOS. Code ouvert, bibliothèque locale, aucune télémétrie.")
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                Text("Une application personnelle, pas une promesse médicale.").font(.system(size: 21, design: .serif))
                Text("Onde propose un environnement sonore configurable. Ses effets sur la concentration ou la méditation ne sont pas établis comme équivalents à ceux de Brain.fm ou d’Endel. Aucun mécanisme propriétaire de ces services n’est reproduit ici.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Text("Code : licence MIT. Synthèses originales : CC0. Vos imports restent privés et ne sont jamais inclus dans les archives du projet.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                Link("Licence MIT", destination: URL(string: "https://opensource.org/license/mit")!).font(.system(size: 11)).tint(Theme.accent)
            }
        }
        ForEach(model.sounds.filter { !$0.imported }) { sound in
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(sound.title).font(.system(size: 14, weight: .medium)); Spacer(); Text(sound.license).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.accent) }
                Text(sound.author).font(.system(size: 11)).foregroundStyle(Theme.muted)
                if sound.source.hasPrefix("https://"), let url = URL(string: sound.source) { Link("Source officielle", destination: url).font(.system(size: 10)).tint(Theme.accent) }
                if sound.license == "CC BY 4.0" {
                    Link("Creative Commons Attribution 4.0 · fichier audio non modifié", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).font(.system(size: 10)).tint(Theme.muted)
                } else { Text("Génération par le script inclus. Les textures naturelles sont synthétisées.").font(.system(size: 10)).foregroundStyle(Theme.muted) }
            }.padding(20).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
