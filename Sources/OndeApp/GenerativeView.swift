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
        PageHeader(eyebrow: "Focus collection · long-form music", title: "A steady rhythm. Music that unfolds.", subtitle: "Seven musical worlds, eight-bar phrases and smooth scene transitions.")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(FocusCompositions.profiles) { profile in SoundProfileCard(profile: profile) }
        }
        DisclosureGroup(isExpanded: $otherProfiles) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(SoundProfile.all.filter { $0.configuration.composition==0 }) { profile in SoundProfileCard(profile: profile) }
            }.padding(.top,16)
        } label: { Text("More soundscapes · Focus, Relax & Meditation").font(.system(size:12,weight:.medium)).foregroundStyle(Theme.muted) }
        GenerativeContinuityPanel()
        if let id = model.generatorConfiguration.profileID, FocusCompositions.ids.contains(id) {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(FocusCompositions.rationale(id)).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                    if id == "sanctuaire" {
                        GeneratorControl(key: "vocals", title: "Vocal presence", detail: "Synthesized vowels. At zero, the same accompaniment continues without voices.")
                    }
                    if ["filigrane", "ambre"].contains(id) {
                        GeneratorControl(key: "piano", title: "Piano presence", detail: "Soft acoustic piano recordings. No added vinyl noise.")
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
                        Label(model.generatorActive && model.playing ? "Continuous rhythm" : "Ready to play", systemImage: "waveform.path")
                            .font(.system(size: 11)).foregroundStyle(Theme.accent(model.mode))
                        Text("100% local · no Endel audio").font(.system(size: 10)).foregroundStyle(Theme.muted)
                    }
                    PillButton(title: model.generatorActive && model.playing ? "Pause" : "Listen", symbol: model.generatorActive && model.playing ? "pause.fill" : "play.fill", primary: true) {
                        if model.generatorActive && model.playing { model.pause() } else { model.startGenerator(model.mode) }
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 23) {
                    if model.generatorConfiguration.composition != 2 {
                    GeneratorControl(key: "punch", title: "Impact", detail: "Defined low-end attacks, without added clicks")
                    GeneratorControl(key: "drive", title: "Drive", detail: "A steady, bouncing eighth-note bass line")
                    GeneratorControl(key: "bass", title: "Bass depth", detail: "A round, centered low end, independent of master volume")
                    GeneratorControl(key: "pulse", title: "Pulse", detail: "A steady pulse without random breaks")
                    }
                    GeneratorControl(key: "density", title: "Note density", detail: "From a minimal bed to a more present, muted motif")
                    GeneratorControl(key: "warmth", title: "Warmth", detail: "Round off the sound and soften bright edges")
                    TempoControl()
                    GeneratorControl(key: "space", title: "Space", detail: "From an intimate room to a spacious reverb")
                }
                DisclosureGroup(isExpanded: $advanced) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 22) {
                        GeneratorControl(key: "brightness", title: "Brightness", detail: "Harmonic presence without artificial hiss")
                        GeneratorControl(key: "movement", title: "Movement", detail: "Slow variations in timbre and stereo placement")
                        GeneratorControl(key: "texture", title: "Harmonic texture", detail: "Build up the harmonic bed, not a noise layer")
                        GeneratorControl(key: "evolution", title: "Evolution", detail: "Develop themes and instrumentation without changing tempo")
                        if model.generatorConfiguration.composition == 0 {
                            GeneratorControl(key: "stability", title: "Harmonic stability", detail: "Hold chords for 32 or 64 bars")
                            GeneratorControl(key: "character", title: "Character", detail: "From muted keys to slowly swelling pads")
                        }
                    }.padding(.top, 20)
                } label: { Text("Fine-tune the sound").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted) }
                Text("Tempo is independent of other controls. Variations stay in the background; the rhythm does not reinvent itself every bar.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
        }
        DisclosureGroup {
            Text("Research informs the use of wordless music, controlled complexity and personal preference. Tempos and harmonies are artistic choices. These compositions are not clinically validated or guaranteed to outperform silence.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).padding(.top, 12)
        } label: { Text("What the evidence supports").font(.system(size: 11)).foregroundStyle(Theme.muted) }
        if model.mode == .meditation { meditationPanel }
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Return to this sound.").font(.system(size: 21, design: .serif))
                    Spacer()
                    Button("Reset this mode's profile") { model.resetGeneratorSettings() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Text("Each soundscape keeps its palette. The seed chooses a path through written phrases and instrumental colors without resetting the stopwatch.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack(spacing: 12) {
                    TextField("Seed", text: $seedText).font(.system(size: 12, design: .monospaced)).textFieldStyle(.roundedBorder).frame(width: 170).onSubmit(applySeed)
                    PillButton(title: "Apply", symbol: "checkmark", action: applySeed)
                    PillButton(title: "New variation", symbol: "shuffle") { model.setGeneratorSeed(UInt64.random(in: 1...4_294_967_295)); seedError = "" }
                    Spacer()
                }
                if !seedError.isEmpty { Text(seedError).foregroundStyle(.orange).font(.system(size: 11)) }
            }
        }
        Panel {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Take the soundscape with you.").font(.system(size: 21, design: .serif))
                    Text(model.generatorExportStatus ?? "The same engine, rendered to an original WAV with its settings.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Picker("Duration", selection: $exportMinutes) { Text("2 min").tag(2); Text("10 min").tag(10); Text("60 min").tag(60) }.frame(width: 125)
                PillButton(title: model.generatorExporting ? "Rendering…" : "Export", symbol: "square.and.arrow.up", primary: true, action: export).disabled(model.generatorExporting)
            }
        }
        Text("Original compositions. No Endel audio. Selecting a profile does not change your chimes or master volume.")
            .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(4)
            .onAppear { seedText = String(model.generatorConfiguration.seed) }
            .onChange(of: model.generatorConfiguration.seed) { _, value in seedText = String(value) }
    }
    var orchestraPanel: some View {
        Panel {
            VStack(alignment:.leading,spacing:20) {
                HStack {
                    VStack(alignment:.leading,spacing:7) {
                        Text("Shape the ensemble.").font(.system(size:23,design:.serif))
                        Text("Strings, woodwinds, percussion and piano · CC0 acoustic recordings").font(.system(size:11)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName:"music.note.list").font(.system(size:26,weight:.light)).foregroundStyle(Theme.accent)
                }
                LazyVGrid(columns:[GridItem(.flexible(),spacing:28),GridItem(.flexible(),spacing:28)],spacing:22) {
                    GeneratorControl(key:"strings",title:"Sustained strings",detail:"Violins, violas and cellos: the body of the ensemble")
                    GeneratorControl(key:"brass",title:"Horns",detail:"Warm depth without a fanfare")
                    GeneratorControl(key:"woods",title:"Woodwinds",detail:"Bassoon and clarinet blended into the harmony")
                    GeneratorControl(key:"harp",title:"Harp",detail:"Articulated notes within the same harmony")
                    GeneratorControl(key:"ostinato",title:"Rhythmic strings",detail:"A recurring motif with alternating recorded takes")
                    GeneratorControl(key:"percussion",title:"Low percussion",detail:"Acoustic timpani and concert bass drum")
                }
                GeneratorControl(key:"orchestra",title:"Orchestra presence",detail:"Balance the orchestra with synthesized textures; bass stays independent")
                Text("Notes are recorded; their arrangement is generated live. No whole-track loops or connection required during playback.").font(.system(size:10)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
        }
    }
    var meditationPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "moon.haze").foregroundStyle(Theme.accent(.meditation))
                    Text("Gradually, less to follow.").font(.system(size: 21, design: .serif)); Spacer()
                    Text(model.generatorConfiguration.settleMinutes == 0 ? "Off" : "\(Int(model.generatorConfiguration.settleMinutes)) min").font(.system(size: 12, design: .monospaced))
                }
                Text("Notes gradually recede while the sound bed continues. Chimes keep the times you selected.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Slider(value: Binding(get: { model.generatorConfiguration.settleMinutes }, set: { model.setGeneratorValue("settleMinutes", $0) }), in: 0...120, step: 5).tint(Theme.accent(.meditation)).accessibilityLabel("Simplification time in minutes")
                HStack { Text("0: off"); Spacer(); Text("120 minutes") }.font(.system(size: 9)).foregroundStyle(Theme.muted)
            }
        }
    }
    func applySeed() {
        guard let seed = UInt64(seedText), seed <= 9_007_199_254_740_991 else { seedError = "Use a whole number between 0 and 2⁵³−1."; return }
        seedError = ""; model.setGeneratorSeed(seed)
    }
    func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Onde-\(model.generatorConfiguration.profileID ?? model.mode.rawValue)-\(model.generatorConfiguration.seed).wav"
        panel.message = "Original render. Ten minutes of WAV audio uses about 106 MB."
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
                    Text("NO ADDED HISS").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted)
                }.frame(height: 15)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Theme.accent(profile.mode).opacity(0.8) : Theme.line, lineWidth: selected ? 1.5 : 1))
        }.buttonStyle(.plain).accessibilityLabel("Play \(profile.title), \(profile.subtitle)")
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
            Text("Stays fixed until you change it").font(.system(size: 10)).foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { model.generatorConfiguration.tempo }, set: { model.setGeneratorValue("tempo", $0) }), in: 40...120, step: 1).tint(Theme.accent(model.mode)).accessibilityLabel("Tempo in beats per minute")
        }
    }
}
struct GeneratorStudioStrip: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.path").font(.system(size: 21, weight: .light)).foregroundStyle(Theme.accent(model.mode))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.generatorActive ? "\(model.generatorConfiguration.displayName) · generated live" : "Choose your soundscape").font(.system(size: 12, weight: .medium))
                Text("Long-form compositions · steady rhythms · deep bass").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer()
            PillButton(title: "Choose & adjust", symbol: "slider.horizontal.3") { model.page = "generative" }
        }.padding(18).background(Theme.panel, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}

struct GenerativeContinuityPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let status = model.generatorSnapshot
            let transition = status["transition"] as? [String: Any] ?? [:]
            let state = transition["state"] as? String ?? "idle"
            Panel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(state == "idle" ? "Music that keeps unfolding" : state == "preparing" ? "Preparing soundscape…" : "Smooth transition", systemImage: "waveform.path")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accent)
                        Spacer()
                        Text("Crossfade: \(Int(model.transitionSeconds)) s").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                    if let error = status["last_error"] as? String { Text(error).font(.system(size: 11)).foregroundStyle(.orange) }
                    if state == "crossfading" {
                        ProgressView(value: Double(transition["progress"] as? Float ?? 0)).tint(Theme.accent)
                    }
                    Text(state == "waiting_for_bar" ? "The transition starts at the next bar boundary." : "The pulse stays familiar. Themes develop over eight bars and the ensemble balance evolves in chapters, without reaching the end of a track.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4)
                    Slider(value: Binding(get: { model.transitionSeconds }, set: model.setTransitionSeconds), in: 2...30, step: 1)
                        .tint(Theme.accent).accessibilityLabel("Transition duration in seconds")
                    if model.generatorActive && model.playing {
                        Text("Phrase \((status["phrase_index"] as? UInt64 ?? 0) + 1) · chapter \((status["chapter_index"] as? UInt64 ?? 0) + 1)")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }
}
