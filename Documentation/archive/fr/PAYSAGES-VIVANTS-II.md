# Onde 1.3 — Paysages vivants II

Moteur : `onde-living-2`. Code MIT ; nouvelles synthèses originales CC0.

## Écriture sonore

Le moteur précédent reposait surtout sur une basse fixe et des notes isolées.
La version II utilise des phrases originales conservées en mémoire et variées,
des réponses instrumentales, six états d'arrangement, plusieurs voicings,
une basse évolutive, des attaques différenciées et de petites irrégularités de timing.
Les états sont Ouverture, Courant, Tissage, Respiration, Résonance et Suspension.

Les timbres comprennent piano feutré synthétique, cordes pincées, résonances
vitreuses, nappes modulées, frappes brossées, graves et air filtré. Des grains
sont tirés exclusivement du propre signal original du moteur : aucun fichier,
échantillon commercial ou modèle entraîné n'est utilisé. Les échos sont croisés et
filtrés, la réverbération est diffuse, les oscillateurs des nappes varient
indépendamment dans l'espace. La basse directe reste centrée.

Prisme privilégie les motifs et contretemps ; Dérive laisse plus de place aux
accords et résonances ; Immersion conserve une matière mouvante puis retire
progressivement les notes et grains selon `settleMinutes`. Les nappes persistent.
Le retrait des détails est indépendant des carillons de méditation.

## Références et portée

Des extraits de démonstration publics ont servi de références acoustiques. Focus et
Relax ont été remesurés avec l'analyseur spectral local existant. Les fondus et
la brièveté des extraits rendent leur dynamique peu représentative d'une longue
session. Aucune mélodie ni portion de leur enregistrement n'est réutilisée.

Les références vidéo Deep Focus, Smart Focus et Relax ont été retrouvées,
mais l'accès audio YouTube échoue dans l'environnement de travail. Il ne faut
pas présenter ce développement comme une analyse de ces bandes-son intégrales.
Ni l'indiscernabilité avec une référence commerciale, ni des effets cognitifs équivalents ne sont établis.

## Utilisation

Ouvrir Paysages vivants. Les noms Prisme, Dérive et Immersion restent inchangés.
Les paramètres et graines personnels sont conservés, ainsi que les ambiances,
imports, volumes et horaires de carillons. Le moteur II remplace le moteur I.

```sh
~/.local/bin/onde generate play focus --seed 42 --launch
~/.local/bin/onde generate play relax --seed 314
~/.local/bin/onde generate play meditation --seed 2718
~/.local/bin/onde generate status
~/.local/bin/onde generate set density 0.56
~/.local/bin/onde generate set texture 0.10
~/.local/bin/onde generate set movement 0.38
~/.local/bin/onde generate render focus "$HOME/Desktop/Prisme-II.wav" --minutes 10 --seed 42
```

Le statut JSON expose aussi `note_events`, `grain_events`, `bars`, `bpm`,
`active_voices`, `harmony_index` et `arrangement_section`. Ce sont des compteurs
musicaux, pas des signaux physiologiques. L'export réinitialise la composition ;
il n'enregistre pas implicitement la session déjà en cours.

## Validation

26 tests unitaires réussis sur Mac, dont les changements harmoniques et de
structure, la stabilité aux réglages extrêmes, les transitions de mode/graine,
et l'arrêt des nouveaux événements discrets après la simplification méditative.
42 contrôles d'intégration du générateur réussis en profil isolé, sortie muette.
Les tests vérifient le rendu réel, les commandes, la persistance et les exports.

Les trois exemples de dix minutes livrés sont des compositions continues,
contrôlées pour les valeurs finies, le niveau crête, l'absence de secondes de
silence numérique après l'introduction et la non-identité des deux premières
minutes. Ces contrôles ne constituent pas une appréciation artistique.

Empreinte SHA256 du cœur C :
`f735f7b0e76bcacf6d4eeb7e34cd5f3b06db5235ea31af8c74f08fe28e84236e`.
