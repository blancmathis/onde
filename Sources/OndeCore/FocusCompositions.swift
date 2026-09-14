import Foundation

/// Seven small, authored vocabularies. The long-form planner develops them without
/// changing genre or promising a clinically established optimum.
public enum FocusCompositions {
    public static let ids = ["ambre", "canopee", "meridien", "sillage", "filigrane", "confluence", "sanctuaire"]
    public static let profiles: [SoundProfile] = [
        make(5, "ambre", "Ambre", "CLAVIER ÉLECTRIQUE · 82 BPM", "Accords veloutés, basse souple et réponses de piano. Des phrases longues, sans souffle lo-fi ajouté.", 82),
        make(6, "canopee", "Canopée", "PERCUSSIONS MÉLODIQUES · 94 BPM", "Résonances de bois, harpe acoustique et cordes graves. Deux motifs qui se répondent, sans improvisation aléatoire.", 94),
        make(7, "meridien", "Méridien", "HOUSE MINIMALE · 108 BPM", "Un grave entraînant, des accords larges et des contretemps réguliers. L'arrangement évolue, jamais de drop.", 108),
        make(1, "sillage", "Sillage", "ÉLECTRONIQUE PROFONDE · 92 BPM", "Une basse articulée et un thème sombre. Questions, réponses et renversements, sans casser le rythme.", 92),
        make(2, "filigrane", "Filigrane", "PIANO ACOUSTIQUE · 78 BPM", "Un piano doux développe des phrases de huit mesures. La main gauche reste un repère, les réponses évoluent.", 78),
        make(3, "confluence", "Confluence", "ORCHESTRE HYBRIDE · 88 BPM", "Violoncelles rythmiques, cordes liées et pupitres qui changent lentement de place dans l'ensemble.", 88),
        make(4, "sanctuaire", "Sanctuaire", "VOCALISES SYNTHÉTISÉES · 86 BPM", "Des voyelles tenues, une harpe qui répond et une basse régulière. L'harmonie respire sans mots.", 86)
    ]
    private static func make(_ score: Double, _ id: String, _ title: String, _ subtitle: String, _ description: String, _ tempo: Double) -> SoundProfile {
        var c = GenerativeSettings()
        c.profileID = id; c.composition = score; c.seed = UInt64(8100 + Int(score)); c.tempo = tempo
        c.stability = 1; c.evolution = 0.38; c.texture = 0; c.movement = 0.14
        c.brightness = 0.30; c.warmth = 0.70; c.settleMinutes = 0
        c.strings = 0; c.brass = 0; c.woods = 0; c.harp = 0; c.ostinato = 0; c.percussion = 0
        switch Int(score) {
        case 1:
            c.bass = 0.88; c.pulse = 0.38; c.drive = 0.66; c.punch = 0.55
            c.space = 0.44; c.density = 0.40; c.character = 0.48; c.orchestra = 0
        case 2:
            c.bass = 0.15; c.pulse = 0; c.drive = 0; c.punch = 0
            c.space = 0.46; c.density = 0.36; c.orchestra = 1; c.piano = 0.87; c.strings = 0.28
        case 3:
            c.bass = 0.78; c.pulse = 0.25; c.drive = 0.39; c.punch = 0.34
            c.space = 0.62; c.density = 0.46; c.orchestra = 1
            c.strings = 0.82; c.brass = 0.40; c.woods = 0.24; c.harp = 0.26; c.ostinato = 0.63; c.percussion = 0.38
        case 4:
            c.bass = 0.78; c.pulse = 0.33; c.drive = 0.39; c.punch = 0.28
            c.space = 0.75; c.density = 0.29; c.orchestra = 0.80; c.vocals = 0.76
            c.strings = 0.42; c.harp = 0.32; c.percussion = 0.18
        case 5:
            c.bass = 0.62; c.pulse = 0.32; c.drive = 0.32; c.punch = 0.24
            c.space = 0.48; c.density = 0.40; c.orchestra = 0.18; c.piano = 0.48
            c.warmth = 0.75; c.brightness = 0.34
        case 6:
            c.bass = 0.59; c.pulse = 0.24; c.drive = 0.30; c.punch = 0.18
            c.space = 0.56; c.density = 0.36; c.orchestra = 0.35
            c.strings = 0.42; c.harp = 0.58; c.percussion = 0.32; c.brightness = 0.35
        default:
            c.bass = 0.85; c.pulse = 0.30; c.drive = 0.72; c.punch = 0.62
            c.space = 0.55; c.density = 0.35; c.orchestra = 0; c.warmth = 0.63; c.brightness = 0.35
        }
        return SoundProfile(id: id, title: title, mode: .focus, subtitle: subtitle, description: description, configuration: c)
    }
    public static func rationale(_ id: String) -> String {
        switch id {
        case "ambre": return "Un clavier électrique synthétisé et quelques réponses de piano enregistré. Huit mesures pour poser, développer puis résoudre une idée, sans solos envahissants."
        case "canopee": return "Des résonateurs de bois synthétisés et une harpe enregistrée. Une écriture entrelacée qui évolue par phrases, pas par suppression aléatoire des temps."
        case "meridien": return "Une assise house stable, des contretemps écrits et une progression longue. Aucun break ou drop destiné à ramener l'attention sur la musique."
        case "sillage": return "Le grave garde son repère, tandis que le thème développe une réponse sur huit mesures. Les choix évoluent à l'intérieur du même univers."
        case "filigrane": return "Le piano acoustique conserve son toucher doux, mais développe des réponses et des renversements plutôt qu'une seule cellule en boucle."
        case "confluence": return "Les pupitres restent coordonnés. Leur équilibre se transforme lentement sur plusieurs minutes, sans que tous changent d'idée à chaque temps."
        case "sanctuaire": return "Chœur synthétisé, pas chanteurs enregistrés. Des notes communes relient les accords ; la harpe développe les réponses. Les voix restent désactivables."
        default: return ""
        }
    }
}
