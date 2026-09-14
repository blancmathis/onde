# Onde 1.6 — recherche et réalisation d'un focus orchestral

Recherche du 14 septembre 2026. Ce document distingue les sources consultées, les choix artistiques d'Onde et les limites des validations. Les éléments d'Endel ne sont ni extraits ni embarqués. Les nouvelles compositions utilisent une banque acoustique CC0 et le moteur de basse original d'Onde.

## 1. Ce qu'il fallait changer

Les versions précédentes travaillaient surtout des oscillateurs, une nappe, des notes synthétiques et le grave. Modifier leur égalisation ne pouvait pas ajouter les articulations, les résonances et les interactions réellement présentes dans un ensemble enregistré. La nouvelle direction est un **orchestre de chambre hybride** : des prises d'instruments pour le timbre, une partition procédurale stable pour l'organisation, une basse électronique pour l'assise.

« Proche d'Endel » n'est pas synonyme d'orchestre symphonique dramatique. Endel explique que ses équipes préparent les éléments et la logique sonore avant l'adaptation en direct [R1]. Deeper Focus est présenté comme une collaboration de techno minimale avec Plastikman, pas comme une œuvre orchestrale [R2]. Nous reprenons le principe d'éléments travaillés et coordonnés, sans prétendre avoir reconstruit leurs fichiers, leur moteur ni leur protocole d'efficacité.

L'objectif artistique propre à Onde est donc : une matière instrumentale riche, une pulsation qui ne change pas au hasard, des accords liés, et aucun crescendo spectaculaire imposé pour surprendre l'auditeur. Ajouter des instruments ne doit pas signifier ajouter des événements qui réclament tous l'attention.

## 2. Ressources étudiées et décisions de licence

| Ressource | Ce qu'elle apporte | Décision pour Onde |
|---|---|---|
| VSCO 2 Community Edition | Instruments d'orchestre enregistrés, versions WAV et SFZ ; licence CC0 [R3–R4]. | Retenue. On peut distribuer les notes dans l'application, les transformer et composer avec elles. |
| VCSL | Collection complémentaire d'instruments et percussions, avec une licence CC0 dans le dépôt original [R5]. | Bonne source complémentaire. Pas ajoutée en masse : le besoin immédiat est un ensemble orchestral cohérent. |
| Virtual Playing Orchestra | Assemblage de différentes banques et travail d'articulation [R6]. | Étudiée, mais pas copiée en bloc : plusieurs origines et licences demandent une vérification par composant. |
| Philharmonia | Prises d'instruments réalisées par des musiciens d'orchestre [R7]. | Non embarquée. La page permet des œuvres musicales, mais exclut la mise à disposition des fichiers comme échantillons ou instrument échantillonné. |
| Spitfire / BBC Symphony Orchestra Discover | Autre voie de composition orchestrale gratuite ou commerciale. Les conditions concernent un instrument sous licence [R8]. | Pas intégrée comme banque redistribuable : l'accès au logiciel ne donne pas automatiquement le droit d'en redistribuer les enregistrements. |
| Formats SFZ et moteurs tiers | Cartographie des notes, articulations, prises alternées [R9]. | Les métadonnées SFZ de VSCO servent à lire les hauteurs correctes. Un petit lecteur natif dédié remplace une dépendance à un plug-in externe. |

Le choix n'est pas « tout ce qui est gratuit ». C'est une sélection dont la provenance peut être conservée, vérifiée et redistribuée avec ce projet public. Les versions commerciales de VSCO ne sont pas assimilées à la Community Edition.

## 3. Pourquoi ces instruments

Les pages d'orchestration de Vienna Symphonic Library décrivent les combinaisons et registres des instruments [R10–R15]. Elles ont servi de guides de timbre, pas de prescriptions médicales.

**Violoncelles et cors.** Leur combinaison donne un noyau médium-grave plus riche qu'une sinusoïde seule. Dans Onde, le violoncelle joue une assise et les cors soutiennent les notes communes. Le cor reste dosé pour ne pas devenir une fanfare.

**Altos et violons.** Les altos remplissent l'intérieur des accords. Les violons donnent de l'ampleur au-dessus, sans être obligés de porter une mélodie dominante. Des attaques et fins graduelles permettent aux groupes successifs de se chevaucher.

**Basson et clarinette.** Ils renforcent les couleurs liées des accords. Ce sont des voix intérieures ; ils ne viennent pas improviser un nouveau solo à chaque mesure.

**Harpe.** Elle articule un contour régulier dans l'harmonie existante. Son rôle est de rendre le mouvement perceptible, sans ajouter des montées et descentes indépendantes du reste.

**Timbales et grosse caisse.** Des frappes graves prolongent l'assise électronique. Pas de cymbales brillantes, de roulements spectaculaires ou de nouveaux accents aléatoires dans ces quatre profils.

Ces principes donnent une partition commune. Le grave électronique, les cordes rythmiques et les touches de harpe utilisent la même horloge. Les changements de timbre ne déplacent pas les temps de la mesure.

## 4. Banque acoustique réellement intégrée

**67 prises**, réparties en neuf instruments et onze groupes d'articulation :

| Groupe | Prises |
|---|---:|
| Ensemble de violons, notes tenues | 6 |
| Ensemble d'altos, notes tenues | 6 |
| Ensemble de violoncelles, notes tenues | 7 |
| Violoncelles, notes courtes | 12 |
| Violons, notes courtes | 8 |
| Cor, notes tenues | 6 |
| Basson, notes tenues | 4 |
| Clarinette, notes tenues | 4 |
| Harpe | 8 |
| Timbales | 4 |
| Grosse caisse d'orchestre | 2 |

Les notes courtes alternent deux prises lorsqu'elles sont disponibles. Cette alternance change la réalisation acoustique, pas la présence de la note ni son instant de départ. Le format SFZ documente ce principe de séquence de prises [R9].

Un détail important : les conventions d'octave diffèrent entre certaines sources. Les hauteurs sont reprises du `pitch_keycenter` des SFZ, et non déduites aveuglément du nom du WAV. Les transpositions utilisent la prise voisine dans le registre couvert.

Le registre contient l'URL et le commit exacts, le SHA-256 du fichier source, son empreinte de blob Git, l'instrument, la hauteur MIDI et l'indice de prise. Les fichiers viennent du commit `440300901dfe9275fd84e0b7763af1f8443ae62e` du dépôt VSCO 2 CE.

À la construction : suppression des silences en bordure avec une courte marge avant l'attaque, retrait de la composante continue, normalisation plafonnée, léger filtrage et fondus de bord. La stéréo est conservée. Il n'y a pas de débruitage agressif ni de couche de souffle synthétique ajoutée. Le grain naturel d'un archet peut rester audible : cela ne signifie pas que les prises seraient absolument silencieuses en dehors de leur fondamentale.

## 5. Les quatre profils

| Profil | Tempo | Rôle musical |
|---|---:|---|
| Atlas | 88 BPM | Cordes amples, cors plus présents, ostinato grave et socle électronique. |
| Ostinato | 100 BPM | Violoncelles articulés, réponses de violons et percussion plus marquée. |
| Aurore | 84 BPM | Harpe et bois davantage présents, équilibre plus aérien. |
| Chambre | 76 BPM | Cordes et bois dominants ; composantes électroniques plus discrètes. |

Ces valeurs sont des choix de composition, pas des fréquences ou tempos « prouvés optimaux ». Tous sont en mode Focus. Les neuf profils antérieurs restent disponibles ; les réglages enregistrés, les volumes et les carillons ne sont pas remplacés.

Dans **Paysages vivants**, les quatre cartes orchestrales sont présentées en premier. Les anciennes ambiances sont rangées sous une section repliable. Les commandes de pupitre sont Cordes liées, Cors, Bois, Harpe, Cordes rythmiques, Percussions graves et Présence de l'orchestre. Les réglages de basses et d'impact restent indépendants.

## 6. Moteur et qualité technique

Le lecteur d'échantillons est un composant C à mémoire préallouée. Les fichiers sont vérifiés et chargés avant le premier rendu. Le chemin audio ne télécharge rien, n'ouvre aucun fichier et n'alloue pas de nouvelles voix. Les buffers des notes sont immuables pendant la lecture.

Une note prend la hauteur source voisine, une durée et une enveloppe progressives. Les parties tenues se chevauchent. Les instruments partagent une réverbération, mais gardent un placement et un niveau de groupe distincts. Le moteur synthétique reste responsable des basses et de l'impact ; ses anciennes nappes et notes reculent quand le réglage Orchestre augmente.

Les exports emploient le même lecteur, la même banque et la même configuration que l'application. Un export peut durer jusqu'à trois heures. Répéter une note d'instrument n'est pas rejouer une piste musicale entière : l'arrangement est calculé pendant le rendu. Un fichier audio n'est donc pas utilisé comme boucle de session.

Si la banque manque ou échoue à la vérification, un profil orchestral signale une erreur. Il ne se fait pas passer silencieusement pour un orchestre en rejouant l'ancien synthétiseur. Le statut expose le nombre de prises chargées, les voix acoustiques actives et les événements orchestraux.

## 7. Ce que la recherche permet de dire sur la concentration

L'étude sur les ambiances personnalisées d'Endel utilise notamment un indicateur de concentration dérivé de l'EEG ; ses liens avec Arctop et Endel doivent être pris en compte [R16]. Elle ne valide pas toutes les musiques qui se rapprochent de leurs timbres.

Des expériences sur les musiques préférées montrent que préférence, tâche et distraction doivent être distinguées [R17]. D'autres expériences ne trouvent pas une amélioration uniforme de l'attention avec de la musique [R18]. Il serait donc incorrect de traduire « plus d'orchestre », « plus de grave » ou « plus d'énergie » en un gain garanti de productivité.

La sélection finale doit se faire sur deux axes séparés : plaisir et confort d'écoute, puis capacité à maintenir une tâche. Une comparaison utile emploie un niveau perçu proche et une tâche comparable. Les mesures de spectre, de niveaux ou de régularité du moteur ne remplacent pas cette évaluation.

**Limites de cette réalisation :** une sélection légère de prises, pas une banque symphonique exhaustive ; pas d'articulations de vrai legato entre chaque paire de notes ; pas de test d'indiscernabilité avec Endel ; pas de validation clinique. La recherche sur leur logique publique n'est pas présentée comme une écoute analytique de toutes leurs intégrales YouTube.

## 8. CLI et compilation

```sh
~/.local/bin/onde generate profile atlas --launch
~/.local/bin/onde generate profile ostinato
~/.local/bin/onde generate profile aurore
~/.local/bin/onde generate profile chambre
~/.local/bin/onde generate set strings 0.8
~/.local/bin/onde generate set brass 0.5
~/.local/bin/onde generate set woods 0.35
~/.local/bin/onde generate set harp 0.4
~/.local/bin/onde generate set ostinato 0.7
~/.local/bin/onde generate set percussion 0.45
~/.local/bin/onde generate status
~/.local/bin/onde generate render atlas "$HOME/Desktop/Atlas.wav" --minutes 10
```

Tous les niveaux de pupitres vont de 0 à 1. La banque est incluse dans l'application publiée. Pour compiler depuis le dépôt : `bash Tools/prepare_orchestra.sh`, puis `bash Tools/build.sh`. Le téléchargement de construction vérifie chaque source. Il n'y a pas de téléchargement d'instrument pendant une session.

Les versions GitHub sont construites pour Apple Silicon et Intel. Le mécanisme de mise à jour existant reste en place. Le code est sous MIT ; la banque acoustique et les nouveaux rendus sont sous CC0. La licence des imports personnels n'est pas modifiée.

## Sources primaires

R1. Endel, technologie et éléments préconçus : https://endel.io/technology

R2. Endel / Plastikman, Deeper Focus : https://deeper.endel.io/

R3. Versilian Studios, VSCO 2 Community Edition et conditions CC0 : https://versilian-studios.com/vsco-community/

R4. VSCO 2 CE, fichiers, licence et branche SFZ : https://github.com/sgossner/VSCO-2-CE

R5. VCSL, licence originale : https://github.com/sgossner/VCSL/blob/master/README.md

R6. Virtual Playing Orchestra, origines des banques : https://virtualplaying.com/virtual-playing-orchestra/

R7. Philharmonia, licence des sound samples : https://philharmonia.co.uk/resources/sound-samples/

R8. Spitfire Audio, End User License Agreement : https://www.spitfireaudio.com/pages/spitfire-audio-end-user-license-agreement

R9. SFZ, alternance des prises : https://sfzformat.com/opcodes/seq_position/ et https://sfzformat.com/tutorials/drum_basics/

R10. Vienna Symphonic Library, cor et combinaisons : https://www.vsl.co.at/academy/brass/horn-f

R11. Vienna Symphonic Library, alto : https://www.vsl.co.at/academy/strings/viola

R12. Vienna Symphonic Library, harpe : https://www.vsl.co.at/academy/strings/harp

R13. Vienna Symphonic Library, basson : https://www.vsl.co.at/academy/woodwinds/bassoon

R14. Vienna Symphonic Library, contrebasse : https://www.vsl.co.at/academy/strings/double-bass

R15. Vienna Symphonic Library, timbales : https://www.vsl.co.at/academy/percussion/timpani

R16. Haruvi et al., 2022, Measuring and Modeling the Effect of Audio on Human Focus : https://www.frontiersin.org/journals/computational-neuroscience/articles/10.3389/fncom.2021.760561/full

R17. Kiss et Linnell, 2024, musique préférée et attention soutenue : https://www.nature.com/articles/s41598-024-60218-z

R18. Nadon et al., 2021, musique/bruit et attention : https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.729037/full
