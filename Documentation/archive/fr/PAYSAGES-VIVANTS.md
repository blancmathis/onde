# Onde 1.2 — Paysages vivants

Trois compositions procédurales originales : **Prisme (Focus)**, **Dérive (Relax)** et **Immersion (Méditation)**. Le moteur synthétise le son en direct, sans fichiers audio, sans serveur, sans modèle d'IA et sans extraits commerciaux. Les anciens sons et ambiances restent disponibles.

## Références étudiées

L'analyse spectrale porte uniquement sur les trois extraits publics de référence déjà présents dans la bibliothèque privée, environ 25, 30 et 24 secondes. Elle ne représente pas le catalogue de référence complet. La FFT de 8192 points, les niveaux RMS et les mesures de stéréo ont guidé le timbre, sans transcription mélodique ni réemploi des fichiers.

| Mesure | Focus | Relax | Sleep |
|---|---:|---:|---:|
| RMS dBFS | -19.08 | -23.89 | -22.28 |
| Énergie 20–100 Hz | 65.19 % | 58.49 % | 17.26 % |
| Énergie 100–300 Hz | 27.85 % | 26.91 % | 52.68 % |
| Énergie 300–1000 Hz | 6.19 % | 13.04 % | 27.54 % |
| Corrélation stéréo | 0.58 | 0.25 | 0.34 |

Les fondus des extraits influencent leur dynamique et ne sont pas des cibles à copier pour une session continue. Une ressemblance spectrale n'est pas une preuve de confusion perceptive ni d'efficacité cognitive équivalente. Aucun essai clinique ni comparaison auditive à l'aveugle n'a été réalisé.

Le moteur utilise ses propres règles musicales et ses propres compositions, adaptées en temps réel.

## Contrôle depuis l'app

Ouvrir **Paysages vivants**, puis choisir Prisme, Dérive ou Immersion. Les sept réglages se conservent séparément pour chaque mode et sont également enregistrés dans les ambiances sauvegardées. Les changements sont lissés.

Immersion retire progressivement les notes et impulsions, sans arrêter les nappes. Le délai est de 30 minutes par défaut ; 0 désactive cette simplification. Ce réglage est indépendant des carillons. Les carillons personnels et leurs horaires ne sont pas réinitialisés par cette mise à jour.

La graine fixe les choix d'une nouvelle composition. Changer la graine en cours de lecture agit sur les événements futurs sans couper les sons déjà actifs : cela ne revient pas au début d'un export correspondant à cette graine.

## CLI

```sh
~/.local/bin/onde generate presets
~/.local/bin/onde generate play focus --seed 42 --launch
~/.local/bin/onde generate play relax --seed 314
~/.local/bin/onde generate play meditation --seed 2718
~/.local/bin/onde generate set density 0.3
~/.local/bin/onde generate set brightness 0.2
~/.local/bin/onde generate set space 0.8
~/.local/bin/onde generate set movement 0.25
~/.local/bin/onde generate set texture 0.1
~/.local/bin/onde generate set pulse 0.15
~/.local/bin/onde generate set evolution 0.2
~/.local/bin/onde generate set settleMinutes 30
~/.local/bin/onde generate seed 2026
~/.local/bin/onde generate status
~/.local/bin/onde mix save 'Immersion personnelle'
~/.local/bin/onde pause
~/.local/bin/onde play
~/.local/bin/onde stop
```

Les sept paramètres musicaux vont de 0 à 1. `settleMinutes` va de 0 à 120. La graine est un entier entre 0 et 2^53−1. `generate defaults` restaure seulement les paramètres de synthèse du mode courant. `silence` désactive aussi le générateur, mais conserve le chronomètre et les carillons. Le volume général à zéro coupe également les carillons.

`generate status` expose le temps effectivement rendu, les événements, le niveau et les erreurs. Le temps de synthèse n'est pas le temps de méditation : le chronomètre de session reste la référence des carillons.

## Export original, sans app ouverte

```sh
~/.local/bin/onde generate render focus "$HOME/Desktop/Prisme-10min.wav" --minutes 10 --seed 42
~/.local/bin/onde generate render meditation "$HOME/Desktop/Immersion-1h.wav" --minutes 60 --seed 2718 --settings '{"space":0.87,"settleMinutes":30}'
```

L'export utilise le même moteur, nouvellement initialisé. WAV stéréo 44.1 kHz / 16 bits, durée de 1 seconde à 3 heures, fondu de fin, manifeste JSON. Aucun fichier existant n'est écrasé. Un export de dix minutes occupe environ 106 Mo en WAV. La même configuration produit le même PCM sur la même plateforme ; de petites différences de calcul flottant sont possibles entre architectures.

## Architecture et licences

`Sources/OndeDSP` : cœur C11, voix préallouées, oscillateurs harmoniques, tines FM, bruit filtré, séquenceur original et réverbération stéréo à huit lignes de délai. Les paramètres sont atomiques. Aucun accès au disque ou au réseau, allocation ou verrou bloquant dans la fonction de rendu.

`GenerativeEngine.swift` : AVAudioSourceNode / Core Audio. `GenerativeRenderer.swift` : export avec le même cœur. `GenerativeSettings.swift` : paramètres par mode. `GenerativeView.swift` : interface native. Le CLI partage le modèle et expose des réponses JSON.

Code MIT ; nouveaux rendus CC0-1.0. Les sons commerciaux de référence restent privés et ne sont jamais incorporés au moteur ou aux archives publiques. Les compositions ne promettent pas les mêmes effets que les références commerciales.
