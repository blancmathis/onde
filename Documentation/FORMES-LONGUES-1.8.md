# Onde 1.8 — des phrases, pas quatre temps en boucle

## Ce qui change

Trois nouvelles compositions : Ambre (clavier électrique, 82 BPM), Canopée (percussions mélodiques, 94 BPM), Méridien (house minimale, 108 BPM). Sillage, Filigrane, Confluence et Sanctuaire conservent leurs identités mais emploient le nouveau développement. Les anciennes préférences, les carillons et les imports restent séparés et conservés.

La répétition courte demeure dans la pulsation. En revanche, la musique ne repose plus seulement sur une cellule de une ou deux mesures. Chaque thème possède seize repères mélodiques sur huit mesures, une première proposition, une réponse et une résolution. Quatre thèmes sont écrits par univers. Ils sont reliés à six accords compatibles et à un parcours d'orchestration.

Les phrases de huit mesures durent environ 18 à 25 secondes dans les sept profils. L'harmonie avance toutes les seize mesures. Un chapitre de 64 mesures (environ 2 min 20 à 3 min 20) choisit un nouvel équilibre entre les pupitres, fondu sur huit secondes. Les décisions ne sont pas prises au hasard à chaque note. La graine et l'indice du chapitre définissent un parcours déterministe dans ce vocabulaire. L'évolution à zéro conserve le même thème et la même harmonie.

Il ne s'agit **pas** d'une promesse d'absence totale de répétition : les thèmes reviennent et le rythme doit rester lisible. Le moteur n'a pas de durée de fin ni de redémarrage de piste, mais aucun test fini ne démontre une infinité de contenu unique. Les exports WAV restent limités à trois heures par fichier pour des raisons pratiques.

## Chaque composition

**Ambre.** Clavier électrique à résonateurs harmoniques originaux, accords espacés et réponses de piano acoustique. Les accents décalés sont écrits à l'avance. Pas de craquements de vinyle ni de souffle lo-fi imposé. Ce n'est pas un enregistrement d'un piano électrique de marque.

**Canopée.** Résonateurs de bois synthétisés, harpe acoustique et violoncelle en soutien. Deux parties intercalées partagent la même harmonie. Le matériau instrumental et le placement des réponses diffèrent réellement d'Ambre.

**Méridien.** House minimale à accords larges, impact grave et contretemps. La progression change, mais la pulsation ne s'arrête pas pour un drop ou une montée. La matière reste électronique, sans batterie bruitée ajoutée.

**Sillage.** La basse conserve son pédalier grave tandis que le thème développe des réponses sur huit mesures. Les nouvelles couleurs ne coupent pas la pulsation.

**Filigrane.** Le piano enregistré développe une main droite plus longue ; la basse acoustique emploie des renversements. Les réponses restent modestes et prévisibles.

**Confluence.** Cordes graves, altos, violons, cors et harpe partagent une partition. Les équilibres changent lentement, pas tous les motifs à la fois.

**Sanctuaire.** Voyelles entièrement synthétisées, sans mots ni identité de chanteur imitée. Les accords se relient lentement et la harpe développe une réponse. Le volume des voix reste indépendant.

## Transitions

La nouvelle scène est allouée, chargée et préparée sur une file de travail, pendant que l'ancienne joue. Une seule instance Core Audio mélange les deux scènes. Le fondu commence au prochain début de mesure de la scène sortante, dure dix secondes par défaut et conserve les queues de réverbération.

Les enveloppes audio sont continues, à pente nulle aux extrémités. Les attaques sortantes reculent avant que les attaques entrantes deviennent fortes, pour éviter de superposer deux batteries très présentes à des tempos différents. Ce n'est pas un beatmatching de DJ : les deux compositions gardent leur tempo. Le passage utilise une transition de textures et un relais rythmique.

Durée réglable de 2 à 30 secondes, séparée des carillons et des réglages musicaux. Les clics rapides ne multiplient pas les moteurs actifs sans limite : deux scènes au plus sont audibles, une cible peut attendre, la dernière cible préparée remplace une cible encore en attente. Pause et silence restent accessibles pendant le fondu. Le chronomètre n'est pas réinitialisé lorsqu'on change entre les compositions Focus.

Le rendu ne charge pas de fichiers, n'alloue pas de voix et ne libère pas de scène. Les anciens moteurs sont rendus au fil de contrôle pour y être détruits. Le volume général reste sous le contrôle de l'utilisateur. Les niveaux internes ont été rapprochés à partir de rendus de référence ; il ne s'agit pas d'une garantie d'égalité de volume perçu pour tous les auditeurs ou appareils.

## Études et limites

1. Kiss & Linnell (2024), *The role of mood and arousal...*, Scientific Reports : https://www.nature.com/articles/s41598-024-60218-z — musique préférée, vigilance, humeur et éveil. Cela soutient le maintien du choix musical ; pas l'existence d'une musique universellement optimale.
2. Orpella et al. (2025), *Effects of music advertised to support focus...*, PLOS ONE : https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0316047 — conditions de musique de travail, vitesse de traitement et humeur. Conditions courtes et liens commerciaux déclarés ; les caractéristiques musicales ne sont pas toutes isolées.
3. Witek et al. (2014), *Syncopation, Body-Movement and Pleasure in Groove Music* : https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0094446 — plaisir et envie de bouger à complexité intermédiaire. Ce n'est pas un essai démontrant un gain de concentration.
4. *Should We Turn off the Music? Music with Lyrics Interferes with Cognitive Tasks* (2023) : https://journalofcognition.org/articles/10.5334/joc.273 — justification pour ne pas ajouter de texte chanté ; les vocalises ne sont pas pour autant prouvées bénéfiques.
5. Vasilev et al., *Distraction by auditory novelty during reading* : https://arxiv.org/abs/2011.00163 — sons inattendus et planification des saccades. Pertinent pour éviter les surgissements, mais pas une comparaison directe de nos musiques.

Ces sources guident une conception, pas une certification. Huit mesures, les tempos, les transitions de dix secondes et les timbres sont des choix musicaux et techniques. Aucune nouvelle fréquence thérapeutique ni modulation rapide n'a été ajoutée. L'agrément et l'effet réel sur le travail demandent des comparaisons personnelles, idéalement à volume perçu comparable.

## Commandes

```sh
onde generate profile ambre --launch
onde generate profile canopee
onde generate profile meridien
onde generate profile sanctuaire
onde generate transition 10
onde generate set evolution 0.4
onde generate status
onde generate render canopee /absolute/Canopee.wav --minutes 60
onde generate transition-render ambre sanctuaire /absolute/Transition.wav --seconds 70 --at 25 --fade 10
```

Le statut expose l'indice de phrase, le chapitre, la variante, l'empreinte des notes planifiées et l'avancement de la transition. L'empreinte décrit une structure musicale : ce n'est pas un score de concentration. Le temps rendu d'une scène est distinct du chronomètre global de session.

Code MIT. Prises acoustiques VSCO 2 CE sous CC0, inchangées par cette mise à jour. Rendus originaux CC0. Aucun son Endel, import personnel ou signal biologique n'est ajouté au dépôt. Aucun nouvel accès aux capteurs ou à l'historique informatique n'est activé.
