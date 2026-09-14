import Foundation

/// Four individually authored scores. Evidence-informed design, not clinical efficacy claims.
/// These values are artistic starting points, not scientifically optimal frequencies.
public enum FocusCompositions {
    public static let ids = ["sillage", "filigrane", "confluence", "sanctuaire"]
    public static let profiles: [SoundProfile] = [
        make(1, "sillage", "Sillage", "ÉLECTRONIQUE PROFONDE · 92 BPM", "Une basse articulée, quatre accents récurrents et des accords sombres. De l'élan, sans surprises.", 92),
        make(2, "filigrane", "Filigrane", "PIANO ACOUSTIQUE · 78 BPM", "Un piano doux, une main gauche stable et une cellule de deux mesures. Peu d'éléments à suivre.", 78),
        make(3, "confluence", "Confluence", "ORCHESTRE HYBRIDE · 88 BPM", "Un ostinato de violoncelles sous des cordes liées. Les pupitres se complètent sans casser la pulsation.", 88),
        make(4, "sanctuaire", "Sanctuaire", "VOCALISES SYNTHÉTISÉES · 86 BPM", "Des couleurs ah, oh, ou en accords tenus. Une assise rythmique, sans mots ni chant soliste.", 86)
    ]
    private static func make(_ score: Double, _ id: String, _ title: String, _ subtitle: String, _ description: String, _ tempo: Double) -> SoundProfile {
        var c = GenerativeSettings()
        c.profileID = id; c.composition = score; c.seed = UInt64(7100 + Int(score)); c.tempo = tempo
        c.stability = 1; c.evolution = 0.10; c.texture = 0; c.movement = 0.10
        c.brightness = 0.28; c.warmth = 0.72; c.settleMinutes = 0
        c.strings = 0; c.brass = 0; c.woods = 0; c.harp = 0; c.ostinato = 0; c.percussion = 0
        switch Int(score) {
        case 1:
            c.bass = 0.88; c.pulse = 0.38; c.drive = 0.68; c.punch = 0.57
            c.space = 0.40; c.density = 0.34; c.character = 0.48; c.orchestra = 0
        case 2:
            c.bass = 0.15; c.pulse = 0; c.drive = 0; c.punch = 0
            c.space = 0.43; c.density = 0.34; c.orchestra = 1; c.piano = 0.87; c.strings = 0.25
        case 3:
            c.bass = 0.78; c.pulse = 0.25; c.drive = 0.39; c.punch = 0.34
            c.space = 0.62; c.density = 0.46; c.orchestra = 1
            c.strings = 0.82; c.brass = 0.40; c.woods = 0.24; c.harp = 0.23; c.ostinato = 0.63; c.percussion = 0.38
        default:
            c.bass = 0.78; c.pulse = 0.33; c.drive = 0.39; c.punch = 0.28
            c.space = 0.75; c.density = 0.26; c.orchestra = 0.80; c.vocals = 0.76
            c.strings = 0.40; c.harp = 0.26; c.percussion = 0.18
        }
        return SoundProfile(id: id, title: title, mode: .focus, subtitle: subtitle, description: description, configuration: c)
    }
    public static func rationale(_ id: String) -> String {
        switch id {
        case "sillage": return "Pour ceux qui aiment être entraînés : rythme affirmé, mais motif et tempo inchangés. Pas de chute de batterie, de paroles ou de souffle ajouté."
        case "filigrane": return "Pour ceux qui préfèrent l'acoustique : registre médium, attaques adoucies et très peu de lignes simultanées. Le piano est enregistré, pas simulé."
        case "confluence": return "Une richesse de timbres plutôt qu'une accumulation de mélodies. Les cordes tenues se chevauchent et l'ostinato reste prévisible."
        case "sanctuaire": return "Des voyelles sans texte, fondues dans l'harmonie. Il s'agit d'un chœur synthétisé, pas de chanteurs enregistrés. Coupez les voix si elles attirent votre attention."
        default: return ""
        }
    }
}
