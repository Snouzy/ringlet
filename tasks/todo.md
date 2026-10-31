# Ringlet v1 — plan

Spec : `docs/specs/2026-10-23-ringlet-design.md`. Une étape = des tests verts avant la suivante.

- [x] 1. Squelette SwiftPM (`RingletCore`, `RingletApp`, `RingletCoreTests`), `.gitignore`, README court, licence MIT
- [x] 2. `RingGeometry` : angles des secteurs, angle → secteur, zone morte, recentrage au bord de l'écran (tests)
- [x] 3. `FileAction` + catalogue : JPG et PNG pour une sélection 100 % HEIC/HEIF, rien sinon (tests)
- [x] 4. `OutputNaming` : `IMG.jpg`, puis `IMG 2.jpg`… (tests)
- [x] 5. `ImageConverter` (ImageIO) : écriture temporaire + renommage, EXIF/orientation conservés, original intact,
        échec par fichier sans arrêter les autres (tests sur une image HEIC générée)
- [x] 6. App barre des menus : icône, menu, lancement à l'ouverture de session
- [x] 7. Lecture de la sélection du Finder (Apple Events) + message si l'autorisation est refusée
- [x] 8. Panneau de l'anneau R2a en SwiftUI : ouverture animée, suivi de la souris, survol, choix au relâché / au clic, Échap
- [x] 9. Raccourci maintenu (Carbon hot key, appui + relâché), branché sur l'anneau
- [x] 10. Bouton de souris (event tap, autorisation Accessibilité à l'activation), désactivé par défaut
- [x] 11. Services « Convertir en JPG / PNG avec Ringlet » (secours du clic droit)
- [x] 12. Réglages (raccourci, bouton, qualité JPG, rayon)
- [ ] 13. `scripts/build-app.sh` + `scripts/install.sh`, essai réel dans le Finder sur de vrais HEIC
- [ ] 14. Relecture complète, README final

## Revue

(à remplir à la fin)

# Positions des options : chaque action à son heure (P3, 31 octobre 2026)

Prototype : https://claude.ai/artifact/BrwoGiMiEV1ZafNJuYVtkB (choix de Mathias : réglage par cadran des heures, anneau P3 « secteurs étirés »).

- [x] 1. `RingGeometry` : secteurs à angles quelconques (`init(angles:)`), chaque secteur va jusqu'à mi-chemin de ses voisins ; `standard(count:)` garde les secteurs égaux (tests)
- [x] 2. `RingHours` : heure par défaut de chaque action, collision → heure libre suivante, textes sans heure répartis sur les heures libres, > 12 actions → secteurs égaux (tests)
- [x] 3. `Descent.inserting` retiré : « Redescendre » a son heure (6 h) ; tests adaptés
- [x] 4. Préférences `fileHours` / `textHours`, anneau construit par heures dans `RingController`, aperçu des réglages aussi
- [x] 5. `RingView` : rayons, graduations et secteur visé d'après les bornes de chaque secteur
- [x] 6. Réglages › Actions : cadran « Positions dans l'anneau », pastilles glissables, Fichiers et dossiers / Textes, bouton Rétablir
- [x] 7. Traductions, README, `swift test` vert, app reconstruite une fois
