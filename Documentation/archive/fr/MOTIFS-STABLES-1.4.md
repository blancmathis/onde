# Onde 1.4 — Motifs stables, basses profondes

Living III répond aux retours sur les ruptures de rythme, le caractère aléatoire et le fond numérique de Living II. Les sons restent des compositions originales ; aucun sample ou moteur propriétaire n'est intégré.

## Six profils

| ID | Nom | Mode | Tempo | Direction |
|---|---|---|---:|---|
| ancrage | Ancrage | Focus | 72 BPM | Motif feutré régulier, basse ronde. |
| abysses | Abysses | Focus profond | 64 BPM | Grave au premier plan, très peu de mélodie. |
| courant | Courant | Focus rythmé | 84 BPM | Motif de touches plus présent, sans omissions aléatoires. |
| velours | Velours | Relax | 56 BPM | Touches douces et espacées. |
| rive | Rive | Relax | 60 BPM | Nappe ample, respiration régulière. |
| immersion | Immersion | Méditation | Pulsation désactivée | Fond continu, détails qui s'effacent. |

Le séquenceur d'Immersion garde une horloge interne à 48 BPM pour ses notes rares. Ce n'est pas une pulsation audible quand `pulse=0`.

## Principes

La grille rythmique est fixe et indépendante de la densité. Aucune omission aléatoire, aucun remplissage imprévisible, aucun changement aléatoire de section. La graine choisit un motif initial qui se répète. Les accords durent 32 à 64 mesures selon `stability`. La musique reste synthétisée en continu ; elle ne rejoue pas un fichier enregistré.

Le grave direct est centré, avec un fond autour de 43,65 Hz et une composante vers 87,31 Hz. Le réglage `bass` est indépendant du volume général. Les nouvelles cartes ne changent pas le volume global.

La couche de bruit synthétique et les fragments granulaires ne sont plus rendus. `texture` dose de la matière harmonique, pas du souffle ajouté. Les attaques sont arrondies, le désaccordage réduit et la modulation des retards est interpolée par échantillon au lieu de sauter par blocs.

## Contrôle

```sh
~/.local/bin/onde generate profiles
~/.local/bin/onde generate profile abysses --launch
~/.local/bin/onde generate profile ancrage
~/.local/bin/onde generate set bass 0.85
~/.local/bin/onde generate set warmth 0.90
~/.local/bin/onde generate set tempo 72
~/.local/bin/onde generate set stability 1
~/.local/bin/onde generate status
~/.local/bin/onde mix save 'Focus grave personnel'
```

Tempo : 40–120 BPM. `settleMinutes` : 0–120, 0 désactive le dépouillement. Les autres paramètres musicaux vont de 0 à 1. Les réglages anciens restent lisibles. Sélectionner explicitement une nouvelle carte applique sa configuration ; `generate play focus` retrouve les réglages personnels de Focus.

`generate status` ajoute `beats`, `sixteenth_ticks`, `min_beat_gap_samples`, `max_beat_gap_samples`, et les indicateurs `noise_layer_enabled=false`, `granular_layer_enabled=false`. Après un changement volontaire du tempo, les compteurs min/max de la session contiennent aussi la transition ; ils ne représentent donc plus une session à tempo unique.

```sh
~/.local/bin/onde generate render abysses "$HOME/Desktop/Abysses-30min.wav" --minutes 30
```

Export original avec le même cœur, sans app ouverte. WAV stéréo 44,1 kHz/16 bits, 1 seconde à 3 heures, manifeste JSON, pas d'écrasement. Une nouvelle initialisation avec la même configuration est reproductible sur une même plateforme. L'export n'utilise pas implicitement le mélange en cours.

## Préservation et diagnostics

Les volumes, les imports, les ambiances sauvegardées et les horaires de carillon restent inchangés. Les nouveaux champs Codable ont des valeurs de repli, sans écraser les anciennes préférences. Les carillons restent indépendants du moteur. `silence` enlève la musique mais conserve chrono et carillons ; le volume général à zéro coupe aussi les carillons.

Le délai du client IPC est de 30 secondes pour supporter une initialisation audio à froid. La lecture initiale d'une requête côté serveur conserve sa limite de 5 secondes. Le CLI ne rejoue pas automatiquement une mutation dont la réponse s'est perdue.

Tests : `swift test -c release -j 2`, `python3 Tools/generative_integration_test.py` et `python3 Tools/profile_integration_test.py`. Les suites d'intégration utilisent un profil temporaire et le volume zéro. Les tests techniques ne prouvent ni l'agrément subjectif ni une efficacité cognitive équivalente à un autre service.

Code original MIT ; nouveaux rendus CC0-1.0. Les imports privés restent hors des archives publiques.
