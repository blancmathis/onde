import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OndeCore

/// The instrument desk is optional. Primary listening never requires this sheet.
struct SoundControlsView: View {
    @EnvironmentObject var model: AppModel
    @State private var seedText = ""
    @State private var seedError = ""
    @State private var exportMinutes = 10
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.currentMusicTitle).font(.system(size: 29, design: .serif))
                Text("Changes are remembered for this music in \(model.mode.title).")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Reset sound") { model.resetCurrentMusicTuning() }
                .help("Restore this music's original settings without changing your default or background.")
        }
        Panel {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26)], spacing: 22) {
                GeneratorControl(key: "bass", title: "Bass", detail: "Weight and depth of the low end")
                GeneratorControl(key: "density", title: model.generatorConfiguration.composition >= 8 ? "Note presence" : "Notes", detail: "From a minimal bed to a fuller pattern")
                GeneratorControl(key: "warmth", title: "Warmth", detail: "Soften bright edges")
                GeneratorControl(key: "space", title: "Space", detail: "Intimate room or spacious reverb")
                if model.generatorConfiguration.vocals > 0 || [4, 11].contains(Int(model.generatorConfiguration.composition)) {
                    GeneratorControl(key: "vocals", title: "Wordless voices", detail: "At zero, the accompaniment continues")
                }
                if model.generatorConfiguration.piano > 0 || [2, 5, 9].contains(Int(model.generatorConfiguration.composition)) {
                    GeneratorControl(key: "piano", title: "Acoustic piano", detail: "The recorded piano part")
                }
            }
        }
        DisclosureGroup(model.generatorConfiguration.composition >= 8 ? "Tone & phrasing" : "Rhythm & detail") {
            Panel {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26)], spacing: 22) {
                    TempoControl()
                    if model.generatorConfiguration.composition < 8 {
                    GeneratorControl(key: "pulse", title: "Pulse", detail: "The underlying rhythmic motion")
                    GeneratorControl(key: "punch", title: "Impact", detail: "Definition of low-end attacks")
                    GeneratorControl(key: "drive", title: "Drive", detail: "The bass line's forward motion")
                    }
                    GeneratorControl(key: "brightness", title: "Brightness", detail: "Harmonic presence")
                    GeneratorControl(key: "movement", title: "Movement", detail: "Slow changes in timbre and stereo")
                    if model.generatorConfiguration.composition < 8 {
                    GeneratorControl(key: "texture", title: "Harmonic texture", detail: "Musical texture, not background noise")
                    }
                    GeneratorControl(key: "evolution", title: "Evolution", detail: "Develop phrases without changing tempo")
                    if model.generatorConfiguration.composition == 0 {
                        GeneratorControl(key: "stability", title: "Harmonic stability", detail: "Longer-held chords")
                        GeneratorControl(key: "character", title: "Character", detail: "Muted keys or slowly swelling pads")
                    }
                }
            }.padding(.top, 12)
        }.font(.system(size: 12, weight: .medium))
        if model.generatorConfiguration.orchestra > 0 {
            DisclosureGroup("Instrument balance") {
                Panel {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26)], spacing: 22) {
                        GeneratorControl(key: "strings", title: "Sustained strings", detail: "Violins, violas and cellos")
                        if model.generatorConfiguration.composition < 8 || model.generatorConfiguration.composition == 10 {
                        GeneratorControl(key: "brass", title: "Horns", detail: "Warm harmonic depth")
                        }
                        if model.generatorConfiguration.composition < 8 || model.generatorConfiguration.composition == 10 {
                        GeneratorControl(key: "woods", title: "Woodwinds", detail: "Bassoon and clarinet")
                        }
                        if model.generatorConfiguration.composition < 8 || [11, 12].contains(Int(model.generatorConfiguration.composition)) {
                        GeneratorControl(key: "harp", title: "Harp", detail: "Articulated notes")
                        }
                        if model.generatorConfiguration.composition < 8 {
                        GeneratorControl(key: "ostinato", title: "Rhythmic strings", detail: "The recurring string motif")
                        }
                        if model.generatorConfiguration.composition < 8 {
                        GeneratorControl(key: "percussion", title: "Low percussion", detail: "Timpani and concert bass drum")
                        }
                        GeneratorControl(key: "orchestra", title: "Orchestra", detail: "Overall acoustic ensemble level")
                    }
                }.padding(.top, 12)
            }.font(.system(size: 12, weight: .medium))
        }
        if model.musicRenderMode == .meditation {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    SmallTimeSlider(title: "Reduce musical details after", seconds: Binding(get: { model.generatorConfiguration.settleMinutes }, set: { model.setGeneratorValue("settleMinutes", $0) }), range: 0...120, unit: "min")
                    Text("Independent of chimes. Zero leaves the arrangement unchanged.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
        }
        DisclosureGroup("Variation & export") {
            VStack(alignment: .leading, spacing: 16) {
                Text("A seed selects a path through the same musical world. It does not change your timer.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                HStack {
                    TextField("Seed", text: $seedText).textFieldStyle(.roundedBorder).frame(width: 185)
                    Button("Apply seed", action: applySeed)
                    Button("New variation") { model.setGeneratorSeed(UInt64.random(in: 1...4_294_967_295)) }
                }
                if !seedError.isEmpty { Text(seedError).font(.system(size: 11)).foregroundStyle(.orange) }
                Divider()
                HStack {
                    Text("Export this music").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Picker("Duration", selection: $exportMinutes) { Text("2 min").tag(2); Text("10 min").tag(10); Text("60 min").tag(60) }.frame(width: 130)
                    Button(model.generatorExporting ? "Rendering…" : "Export WAV…", action: export).disabled(model.generatorExporting)
                }
                if let status = model.generatorExportStatus { Text(status).font(.system(size: 11)).foregroundStyle(Theme.muted) }
            }.padding(.top, 16)
        }.font(.system(size: 12, weight: .medium))
        .onAppear { seedText = String(model.generatorConfiguration.seed) }
        .onChange(of: model.generatorConfiguration.seed) { _, seed in seedText = String(seed) }
    }
    func applySeed() {
        guard let seed = UInt64(seedText), seed <= 9_007_199_254_740_991 else { seedError = "Use a whole number between 0 and 2^53-1."; return }
        seedError = ""; model.setGeneratorSeed(seed)
    }
    func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Onde-\(model.generatorConfiguration.profileID ?? model.mode.rawValue).wav"
        panel.message = "Original WAV export. Ten minutes uses about 106 MB."
        if panel.runModal() == .OK, let url = panel.url { model.exportGenerator(seconds: Double(exportMinutes * 60), path: url.path) }
    }
}
struct GeneratorControl: View {
    @EnvironmentObject var model: AppModel
    let key: String; let title: String; let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold)); Spacer()
                Text("\(Int(model.generatorConfiguration.value(key) * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
            }
            Text(detail).font(.system(size: 10)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Slider(value: Binding(get: { model.generatorConfiguration.value(key) }, set: { model.setGeneratorValue(key, $0) }), in: 0...1)
                .tint(Theme.accent(model.mode)).accessibilityLabel(title)
        }
    }
}
struct TempoControl: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text("Tempo").font(.system(size: 12, weight: .semibold)); Spacer(); Text("\(Int(model.generatorConfiguration.tempo)) BPM").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted) }
            Text("Stays fixed until you change it").font(.system(size: 10)).foregroundStyle(Theme.muted)
            Slider(value: Binding(get: { model.generatorConfiguration.tempo }, set: { model.setGeneratorValue("tempo", $0) }), in: 40...120, step: 1)
                .tint(Theme.accent(model.mode)).accessibilityLabel("Tempo in beats per minute")
        }
    }
}
