import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OndeCore

struct GenerativeView: View {
    @EnvironmentObject var model: AppModel
    @State private var seedText = ""
    @State private var exportMinutes = 10
    @State private var seedError = ""
    @State private var advanced = false
    @State private var otherProfiles = false
    var body: some View {
        PageHeader(eyebrow: "Collection Focus · quatre partitions originales", title: "Trouvez votre rythme. Gardez-le.", subtitle: "Quatre univers soignés, sans paroles, sans changement automatique de style.")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(FocusCompositions.profiles) { profile in SoundProfileCard(profile: profile) }
        }
        DisclosureGroup(isExpanded: $otherProfiles) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(SoundProfile.all.filter { $0.configuration.composition==0 }) { profile in SoundProfileCard(profile: profile) }
            }.padding(.top,16)
        } label: { Text("Les autres paysages · Focus, Relax et Méditation").font(.system(size:12,weight:.medium)).foregroundStyle(Theme.muted) }
        if let id = model.generatorConfiguration.profileID, FocusCompositions.ids.contains(id) {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(FocusCompositions.rationale(id)).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                    if id == "sanctuaire" {
                        GeneratorControl(key: "vocals", title: "Présence des voix", detail: "Voyelles synthétisées. À zéro : le même accompagnement, sans voix.")
                    }
                    if id == "filigrane" {
                        GeneratorControl(key: "piano", title: "Présence du piano", detail: "Prises de piano acoustique doux ; sans bruit de vinyle ajouté.")
                    }
                }
            }
        }
        if model.generatorConfiguration.orchestra>0 && model.generatorConfiguration.composition != 2 && model.generatorConfiguration.composition != 4 { orchestraPanel }
        Panel {
            VStack(alignment: .leading, spacing: 23) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: model.mode.title, color: Theme.accent(model.mode))
                        Text(model.generatorConfiguration.displayName).font(.system(size: 28, design: .serif))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Label(model.generatorActive && model.playing ? "Pulsation continue" : "Prêt à écouter", systemImage: "waveform.path")
                            .font(.system(size: 11)).foregroundStyle(Theme.accent(model.mode))
                        Text("100 % local · aucune piste Endel").font(.system(size: 10)).foregroundStyle(Theme.muted)
                    }
                    PillButton(title: model.generatorActive && model.playing ? "Pause" : "Écouter", symbol: model.generatorActive && model.playing ? "pause.fill" : "play.fill", primary: true) {
                        if model.generatorActive && model.playing { model.pause() } else { model.startGenerator(model.mode) }
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 23) {
                    if model.generatorConfiguration.composition != 2 {
                    GeneratorControl(key: "punch", title: "Impact", detail: "Des attaques graves franches, sans claquement ajouté")
                    GeneratorControl(key: "drive", title: "Entraînement", detail: "Un rebond de basse à la croche, toujours régulier")
                    GeneratorControl(key: "bass", title: "Profondeur des basses", detail: "Un grave rond et centré, sans augmenter le volume général")
                    GeneratorControl(key: "pulse", title: "Présence du rythme", detail: "Une pulsation régulière, sans ruptures aléatoires")
                    }
                    GeneratorControl(key: "density", title: "Présence des notes", detail: "Du fond minimal au motif feutré plus présent")
                    GeneratorControl(key: "warmth", title: "Douceur", detail: "Arrondir le son et atténuer les contours brillants")
                    TempoControl()
                    GeneratorControl(key: "space", title: "Espace", detail: "De l'intimité à une réverbération plus ample")
                }
                DisclosureGroup(isExpanded: $advanced) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 22) {
                        GeneratorControl(key: "brightness", title: "Lumière", detail: "La présence des harmoniques, sans souffle artificiel")
                        GeneratorControl(key: "movement", title: "Mouvement", detail: "De lentes nuances du timbre et de la stéréo")
                        GeneratorControl(key: "texture", title: "Matière harmonique", detail: "Renforcer la nappe, pas ajouter du grésillement")
                        GeneratorControl(key: "evolution", title: "Évolution", detail: "Nuances lentes, sans changer le tempo")
                        if model.generatorConfiguration.composition == 0 {
                            GeneratorControl(key: "stability", title: "Stabilité harmonique", detail: "Accords maintenus 32 ou 64 mesures")
                            GeneratorControl(key: "character", title: "Caractère", detail: "Des touches feutrées aux nappes à attaque lente")
                        }
                    }.padding(.top, 20)
                } label: { Text("Affiner le timbre").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted) }
                Text("Le tempo est indépendant des autres réglages. Les variations restent en arrière-plan ; le rythme ne se réinvente pas à chaque mesure.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
        }
        DisclosureGroup {
            Text("La recherche guide le choix sans paroles, la complexité contrôlée et les préférences. Les tempos et les accords sont des choix musicaux. Aucune de ces pièces ne possède de validation clinique ni de garantie de supériorité au silence.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).padding(.top, 12)
        } label: { Text("Ce que les études permettent de dire").font(.system(size: 11)).foregroundStyle(Theme.muted) }
        if model.mode == .meditation { meditationPanel }
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Retrouver cette couleur.").font(.system(size: 21, design: .serif))
                    Spacer()
                    Button("Profil du mode par défaut") { model.resetGeneratorSettings() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Text("Les quatre partitions gardent leurs motifs composés. La graine renouvelle les nuances de timbre et les prises, sans changer le style ni remettre le chronomètre à zéro.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack(spacing: 12) {
                    TextField("Graine", text: $seedText).font(.system(size: 12, design: .monospaced)).textFieldStyle(.roundedBorder).frame(width: 170).onSubmit(applySeed)
                    PillButton(title: "Appliquer", symbol: "checkmark", action: applySeed)
                    PillButton(title: "Autre nuance", symbol: "shuffle") { model.setGeneratorSeed(UInt64.random(in: 1...4_294_967_295)); seedError = "" }
                    Spacer()
                }
                if !seedError.isEmpty { Text(seedError).foregroundStyle(.orange).font(.system(size: 11)) }
            }
        }
        Panel {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Emporter le paysage.").font(.system(size: 21, design: .serif))
                    Text(model.generatorExportStatus ?? "Le même moteur, dans un fichier WAV original avec ses réglages.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Picker("Durée", selection: $exportMinutes) { Text("2 min").tag(2); Text("10 min").tag(10); Text("60 min").tag(60) }.frame(width: 125)
                PillButton(title: model.generatorExporting ? "Création…" : "Exporter", symbol: "square.and.arrow.up", primary: true, action: export).disabled(model.generatorExporting)
            }
        }
        Text("Compositions originales. Aucun son Endel utilisé. Le choix d'un profil ne modifie ni vos carillons ni votre volume général.")
            .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(4)
            .onAppear { seedText = String(model.generatorConfiguration.seed) }
            .onChange(of: model.generatorConfiguration.seed) { _, value in seedText = String(value) }
    }
    var orchestraPanel: some View {
        Panel {
            VStack(alignment:.leading,spacing:20) {
                HStack {
                    VStack(alignment:.leading,spacing:7) {
                        Text("Diriger les pupitres.").font(.system(size:23,design:.serif))
                        Text("Cordes, bois, percussions et piano · prises acoustiques CC0").font(.system(size:11)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName:"music.note.list").font(.system(size:26,weight:.light)).foregroundStyle(Theme.accent)
                }
                LazyVGrid(columns:[GridItem(.flexible(),spacing:28),GridItem(.flexible(),spacing:28)],spacing:22) {
                    GeneratorControl(key:"strings",title:"Cordes liées",detail:"Violons, altos et violoncelles : le corps de l’ensemble")
                    GeneratorControl(key:"brass",title:"Cors",detail:"Une profondeur chaude, sans fanfare")
                    GeneratorControl(key:"woods",title:"Bois",detail:"Basson et clarinette fondus dans les accords")
                    GeneratorControl(key:"harp",title:"Harpe",detail:"Des notes articulées dans la même harmonie")
                    GeneratorControl(key:"ostinato",title:"Cordes rythmiques",detail:"Un motif répété, avec alternance des prises")
                    GeneratorControl(key:"percussion",title:"Percussions graves",detail:"Timbales et grosse caisse acoustique")
                }
                GeneratorControl(key:"orchestra",title:"Présence de l’orchestre",detail:"L’équilibre avec les textures synthétiques ; les basses restent indépendantes")
                Text("Les notes sont enregistrées ; leur arrangement est composé en direct. Aucune boucle de morceau, aucune connexion pendant l’écoute.").font(.system(size:10)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
        }
    }
    var meditationPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "moon.haze").foregroundStyle(Theme.accent(.meditation))
                    Text("Peu à peu, moins à suivre.").font(.system(size: 21, design: .serif)); Spacer()
                    Text(model.generatorConfiguration.settleMinutes == 0 ? "Désactivé" : "\(Int(model.generatorConfiguration.settleMinutes)) min").font(.system(size: 12, design: .monospaced))
                }
                Text("Les notes s'effacent progressivement ; le fond continue. Les carillons gardent les horaires que vous avez choisis.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Slider(value: Binding(get: { model.generatorConfiguration.settleMinutes }, set: { model.setGeneratorValue("settleMinutes", $0) }), in: 0...120, step: 5).tint(Theme.accent(.meditation)).accessibilityLabel("Dépouillement en minutes")
                HStack { Text("0 : désactivé"); Spacer(); Text("120 minutes") }.font(.system(size: 9)).foregroundStyle(Theme.muted)
            }
        }
    }
    func applySeed() {
        guard let seed = UInt64(seedText), seed <= 9_007_199_254_740_991 else { seedError = "Utilisez un entier compris entre 0 et 2⁵³−1."; return }
        seedError = ""; model.setGeneratorSeed(seed)
    }
    func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Onde-\(model.generatorConfiguration.profileID ?? model.mode.rawValue)-\(model.generatorConfiguration.seed).wav"
        panel.message = "Rendu original. Le WAV occupe environ 106 Mo pour dix minutes."
        if panel.runModal() == .OK, let url = panel.url { model.exportGenerator(seconds: Double(exportMinutes * 60), path: url.path) }
    }
}
struct SoundProfileCard: View {
    @EnvironmentObject var model: AppModel
    let profile: SoundProfile
    var selected: Bool { model.generatorActive && model.generatorConfiguration.profileID == profile.id }
    var body: some View {
        Button { model.startSoundProfile(profile.id) } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: profile.id == "abysses" ? "waveform.path" : profile.mode.symbol).font(.system(size: 20, weight: .light))
                    Spacer()
                    Image(systemName: selected && model.playing ? "waveform" : selected ? "checkmark.circle.fill" : "play.circle").font(.system(size: 17))
                }.foregroundStyle(Theme.accent(profile.mode))
                Text(profile.title).font(.system(size: 26, design: .serif)).foregroundStyle(Theme.ink)
                Text(profile.subtitle).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Theme.accent(profile.mode))
                Text(profile.description).font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).frame(height: 52, alignment: .topLeading)
                HStack(spacing: 3) {
                    ForEach(0..<16, id: \.self) { i in
                        Capsule().fill(Theme.accent(profile.mode).opacity(i%4 == 0 ? 0.65 : 0.22)).frame(width: 4, height: i%4 == 0 ? 14 : 7)
                    }
                    Spacer()
                    Text("SANS SOUFFLE").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted)
                }.frame(height: 15)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Theme.accent(profile.mode).opacity(0.8) : Theme.line, lineWidth: selected ? 1.5 : 1))
        }.buttonStyle(.plain).accessibilityLabel("Écouter \(profile.title), \(profile.subtitle)")
    }
}
struct GeneratorControl: View {
    @EnvironmentObject var model: AppModel
    let key: String; let title: String; let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.system(size: 12, weight: .semibold)); Spacer(); Text("\(Int(model.generatorConfiguration.value(key) * 100)) %").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted) }
            Text(detail).font(.system(size: 10)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Slider(value: Binding(get: { model.generatorConfiguration.value(key) }, set: { model.setGeneratorValue(key, $0) }), in: 0...1).tint(Theme.accent(model.mode)).accessibilityLabel(title)
        }
    }
}
struct TempoControl: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Tempo").font(.system(size: 12, weight: .semibold)); Spacer(); Text("\(Int(model.generatorConfiguration.tempo)) BPM").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted) }
            Text("Fixe tant que vous ne le changez pas").font(.system(size: 10)).foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { model.generatorConfiguration.tempo }, set: { model.setGeneratorValue("tempo", $0) }), in: 40...120, step: 1).tint(Theme.accent(model.mode)).accessibilityLabel("Tempo en battements par minute")
        }
    }
}
struct GeneratorStudioStrip: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.path").font(.system(size: 21, weight: .light)).foregroundStyle(Theme.accent(model.mode))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.generatorActive ? "\(model.generatorConfiguration.displayName) · composé en direct" : "Choisissez votre paysage sonore").font(.system(size: 12, weight: .medium))
                Text("Six profils · rythmes stables · basses profondes").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer()
            PillButton(title: "Choisir & ajuster", symbol: "slider.horizontal.3") { model.page = "generative" }
        }.padding(18).background(Theme.panel, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}
