import Foundation

/// Stable backwards-compatible controls. Missing v1.4 fields acquire conservative defaults.
public struct GenerativeSettings: Codable, Equatable {
    public var seed: UInt64 = 42
    public var density: Double = 0.30
    public var brightness: Double = 0.16
    public var movement: Double = 0.12
    public var space: Double = 0.54
    public var texture: Double = 0.04
    public var pulse: Double = 0.64
    public var evolution: Double = 0.12
    public var settleMinutes: Double = 0
    public var bass: Double = 0.78
    public var tempo: Double = 72
    public var stability: Double = 0.98
    public var warmth: Double = 0.86
    public var character: Double = 0.20
    public var drive: Double = 0
    public var punch: Double = 0
    public var orchestra: Double = 0
    public var strings: Double = 0.5
    public var brass: Double = 0.5
    public var woods: Double = 0.5
    public var harp: Double = 0.5
    public var ostinato: Double = 0.5
    public var percussion: Double = 0.5
    public var composition: Double = 0
    public var vocals: Double = 0
    public var piano: Double = 0
    public var profileID: String? = nil
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case seed, density, brightness, movement, space, texture, pulse, evolution, settleMinutes
        case bass, tempo, stability, warmth, character, drive, punch, orchestra, strings, brass, woods, harp, ostinato, percussion, composition, vocals, piano, profileID
    }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        seed = try c.decodeIfPresent(UInt64.self, forKey: .seed) ?? seed
        density = try c.decodeIfPresent(Double.self, forKey: .density) ?? density
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? brightness
        movement = try c.decodeIfPresent(Double.self, forKey: .movement) ?? movement
        space = try c.decodeIfPresent(Double.self, forKey: .space) ?? space
        texture = try c.decodeIfPresent(Double.self, forKey: .texture) ?? texture
        pulse = try c.decodeIfPresent(Double.self, forKey: .pulse) ?? pulse
        evolution = try c.decodeIfPresent(Double.self, forKey: .evolution) ?? evolution
        settleMinutes = try c.decodeIfPresent(Double.self, forKey: .settleMinutes) ?? settleMinutes
        bass = try c.decodeIfPresent(Double.self, forKey: .bass) ?? bass
        tempo = try c.decodeIfPresent(Double.self, forKey: .tempo) ?? tempo
        stability = try c.decodeIfPresent(Double.self, forKey: .stability) ?? stability
        warmth = try c.decodeIfPresent(Double.self, forKey: .warmth) ?? warmth
        character = try c.decodeIfPresent(Double.self, forKey: .character) ?? character
        drive = try c.decodeIfPresent(Double.self, forKey: .drive) ?? 0
        punch = try c.decodeIfPresent(Double.self, forKey: .punch) ?? 0
        orchestra = try c.decodeIfPresent(Double.self, forKey: .orchestra) ?? orchestra
        strings = try c.decodeIfPresent(Double.self, forKey: .strings) ?? strings
        brass = try c.decodeIfPresent(Double.self, forKey: .brass) ?? brass
        woods = try c.decodeIfPresent(Double.self, forKey: .woods) ?? woods
        harp = try c.decodeIfPresent(Double.self, forKey: .harp) ?? harp
        ostinato = try c.decodeIfPresent(Double.self, forKey: .ostinato) ?? ostinato
        percussion = try c.decodeIfPresent(Double.self, forKey: .percussion) ?? percussion
        composition = try c.decodeIfPresent(Double.self, forKey: .composition) ?? 0
        vocals = try c.decodeIfPresent(Double.self, forKey: .vocals) ?? 0
        piano = try c.decodeIfPresent(Double.self, forKey: .piano) ?? 0
        profileID = try c.decodeIfPresent(String.self, forKey: .profileID)
    }
    public static let keys = ["density", "brightness", "movement", "space", "texture", "pulse", "evolution", "settleMinutes", "bass", "tempo", "stability", "warmth", "character", "drive", "punch", "orchestra", "strings", "brass", "woods", "harp", "ostinato", "percussion", "composition", "vocals", "piano"]
    public static func preset(_ mode: SessionMode) -> Self {
        switch mode {
        case .focus: return SoundProfile.find("elan")!.configuration
        case .relax: return SoundProfile.find("velours")!.configuration
        case .meditation: return SoundProfile.find("immersion")!.configuration
        }
    }
    public static func title(_ mode: SessionMode) -> String {
        switch mode { case .focus: return "Élan"; case .relax: return "Velours"; case .meditation: return "Immersion" }
    }
    public var displayName: String { profileID.flatMap { SoundProfile.find($0)?.title } ?? "Paysage personnel" }
    /// The first eight ABI slots predate gain (slot 8). New controls start at slot 9.
    public var values: [Double] { [density, brightness, movement, space, texture, pulse, evolution, settleMinutes, bass, tempo, stability, warmth, character, drive, punch, orchestra, strings, brass, woods, harp, ostinato, percussion, composition, vocals, piano] }
    public static func dspIndex(_ index: Int) -> Int32 { Int32(index < 8 ? index : index + 1) }
    public func value(_ key: String) -> Double { Self.keys.firstIndex(of: key).map { values[$0] } ?? 0 }
    public static func range(_ key: String) -> ClosedRange<Double> { key == "composition" ? 0...4 : key == "tempo" ? 40...120 : key == "settleMinutes" ? 0...120 : 0...1 }
    public mutating func set(_ key: String, _ value: Double) throws {
        guard Self.keys.contains(key) else { throw OndeError("invalid_key", "Generator keys: \(Self.keys.joined(separator: ", ")).") }
        let range = Self.range(key)
        guard value.isFinite, range.contains(value), (key != "composition" || value.rounded(.down) == value) else { throw OndeError("invalid_argument", "\(key) must be a number in \(range.lowerBound)...\(range.upperBound).") }
        switch key {
        case "density": density = value
        case "brightness": brightness = value
        case "movement": movement = value
        case "space": space = value
        case "texture": texture = value
        case "pulse": pulse = value
        case "evolution": evolution = value
        case "settleMinutes": settleMinutes = value
        case "bass": bass = value
        case "tempo": tempo = value
        case "stability": stability = value
        case "warmth": warmth = value
        case "character": character = value
        case "drive": drive = value
        case "punch": punch = value
        case "orchestra": orchestra = value
        case "strings": strings = value
        case "brass": brass = value
        case "woods": woods = value
        case "harp": harp = value
        case "ostinato": ostinato = value
        case "percussion": percussion = value
        case "composition": composition = value
        case "vocals": vocals = value
        default: piano = value
        }
    }
    public func validated() throws -> Self {
        var copy = self
        for (k, v) in zip(Self.keys, values) { try copy.set(k, v) }
        guard seed <= 9_007_199_254_740_991 else { throw OndeError("invalid_seed", "Seed must be an exact JSON integer <= 2^53-1.") }
        return copy
    }
}
public struct SoundProfile: Identifiable, Codable {
    public let id: String
    public let title: String
    public let mode: SessionMode
    public let subtitle: String
    public let description: String
    public let configuration: GenerativeSettings
    private static func make(_ id: String, _ title: String, _ mode: SessionMode, _ subtitle: String, _ description: String, _ seed: UInt64, _ d: Double, _ b: Double, _ m: Double, _ sp: Double, _ tx: Double, _ p: Double, _ e: Double, _ settle: Double, _ bass: Double, _ tempo: Double, _ stability: Double, _ warmth: Double, _ ch: Double) -> Self {
        var c = GenerativeSettings(); c.seed = seed; c.density = d; c.brightness = b; c.movement = m; c.space = sp; c.texture = tx; c.pulse = p; c.evolution = e; c.settleMinutes = settle; c.bass = bass; c.tempo = tempo; c.stability = stability; c.warmth = warmth; c.character = ch; c.profileID = id
        return .init(id: id, title: title, mode: mode, subtitle: subtitle, description: description, configuration: c)
    }
    private static func energetic(_ id: String, _ title: String, _ description: String, _ tempo: Double, _ bass: Double, _ drive: Double, _ punch: Double, _ density: Double, _ seed: UInt64) -> Self {
        var c = GenerativeSettings(); c.profileID=id; c.seed=seed
        c.tempo=tempo; c.bass=bass; c.drive=drive; c.punch=punch; c.density=density
        c.brightness=0.30; c.warmth=0.65; c.space=0.38; c.movement=0.17
        c.pulse=0.55; c.texture=0.035; c.evolution=0.1; c.stability=1
        c.character=id == "traction" ? 0.50 : 0.18
        return .init(id:id, title:title, mode:.focus, subtitle:"FOCUS ÉNERGIQUE · \(Int(tempo)) BPM", description:description, configuration:c)
    }
    private static func ensemble(_ id:String,_ title:String,_ description:String,_ tempo:Double,_ seed:UInt64,_ strings:Double,_ brass:Double,_ woods:Double,_ harp:Double,_ ostinato:Double,_ percussion:Double,_ bass:Double,_ drive:Double,_ punch:Double,_ density:Double) -> Self {
        var c=GenerativeSettings();c.profileID=id;c.seed=seed;c.tempo=tempo;c.orchestra=1
        c.strings=strings;c.brass=brass;c.woods=woods;c.harp=harp;c.ostinato=ostinato;c.percussion=percussion
        c.bass=bass;c.drive=drive;c.punch=punch;c.density=density;c.brightness=0.34;c.warmth=0.72
        c.space=0.66;c.movement=0.10;c.pulse=0.28;c.evolution=0.12;c.stability=0.98;c.texture=0;c.character=0.18
        return .init(id:id,title:title,mode:.focus,subtitle:"ORCHESTRE · \(Int(tempo)) BPM",description:description,configuration:c)
    }
    public static let all: [Self] = FocusCompositions.profiles + [
        ensemble("atlas","Atlas","Un ensemble ample : cordes graves, cors et pulsation profonde. Une même partition, sans rupture.",88,6040,0.84,0.68,0.30,0.23,0.57,0.47,0.83,0.35,0.34,0.42),
        ensemble("ostinato","Ostinato","Violoncelles articulés, cordes en réponse et timbales. Le plus entraînant des quatre orchestres.",100,6041,0.56,0.34,0.18,0.35,0.98,0.70,0.85,0.58,0.50,0.53),
        ensemble("aurore","Aurore","Cordes lumineuses, harpe et bois chauds. Un mouvement régulier, plus aérien.",84,6042,0.68,0.15,0.66,0.72,0.36,0.18,0.65,0.21,0.17,0.39),
        ensemble("chambre","Chambre","Un orchestre intime, plus acoustique : cordes et bois liés, quelques touches de harpe.",76,6043,0.88,0.22,0.58,0.43,0.25,0.16,0.54,0.08,0.06,0.28),
        energetic("elan", "Élan", "Basses rebondissantes et attaques nettes. Un motif stable pour entrer dans l'action.", 88, 0.88, 0.72, 0.65, 0.43, 2042),
        energetic("reacteur", "Réacteur", "L'impact le plus marqué. Un grave massif, rythmé, avec très peu de mélodie.", 96, 0.98, 0.92, 0.90, 0.10, 3042),
        energetic("traction", "Traction", "Un mouvement rapide, des basses articulées et des touches régulières.", 104, 0.80, 0.78, 0.60, 0.63, 4083),
        make("ancrage", "Ancrage", .focus, "FOCUS · 72 BPM", "Une pulsation ronde, une basse profonde et un motif feutré qui reste en place.", 42, 0.30,0.16,0.12,0.54,0.04,0.64,0.12,0, 0.78,72,0.98,0.86,0.20),
        make("abysses", "Abysses", .focus, "FOCUS PROFOND · 64 BPM", "Le grave au premier plan. Très peu de notes, une continuité dense et enveloppante.", 1042, 0.035,0.07,0.07,0.49,0.01,0.78,0.06,0, 0.98,64,1,0.97,0.86),
        make("courant", "Courant", .focus, "FOCUS RYTHMÉ · 84 BPM", "Un motif de touches plus présent, régulier et doux, posé sur des basses rondes.", 83, 0.53,0.24,0.12,0.43,0.025,0.55,0.15,0, 0.66,84,0.96,0.78,0.48),
        make("velours", "Velours", .relax, "RELAX · 56 BPM", "Des touches chaudes et espacées, sans cassure ni bruit de fond ajouté.", 314, 0.22,0.16,0.13,0.76,0.03,0.04,0.12,0, 0.54,56,0.96,0.90,0.15),
        make("rive", "Rive", .relax, "RELAX · 60 BPM", "Une nappe ample et une respiration très régulière, avec moins de mélodie.", 718, 0.085,0.12,0.18,0.81,0.04,0.22,0.08,0, 0.64,60,1,0.92,0.88),
        make("immersion", "Immersion", .meditation, "MÉDITATION · SANS BATTEMENT", "Un fond continu et doux. Les détails s'effacent sans interrompre votre pratique.", 2718, 0.08,0.10,0.08,0.82,0.02,0,0.06,30, 0.58,48,1,0.95,0.90)
    ]
    public static func find(_ id: String) -> Self? { all.first { $0.id == id } }
}
extension SessionMode {
    public var dspMode: Int32 { switch self { case .focus: return 0; case .relax: return 1; case .meditation: return 2 } }
}
extension Sound {
    public static let living = Sound(id: "living", title: "Paysage vivant", subtitle: "Motifs stables · synthèse en direct", symbol: "waveform.path.ecg", kind: "Génératif", filename: "", author: "Onde · composition procédurale originale", license: "CC0-1.0", source: "Sources/OndeDSP/OndeDSP.c · aucune piste Endel utilisée")
}
