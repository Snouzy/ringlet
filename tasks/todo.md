# Ringlet v1 — plan

Spec : `docs/specs/2026-10-23-ringlet-design.md`. Une étape = des tests verts avant la suivante.

- [x] 1. Squelette SwiftPM (`RingletCore`, `RingletApp`, `RingletCoreTests`), `.gitignore`, README court, licence MIT
- [x] 2. `RingGeometry` : angles des secteurs, angle → secteur, zone morte, recentrage au bord de l'écran (tests)
- [x] 3. `FileAction` + catalogue : JPG et PNG pour une sélection 100 % HEIC/HEIF, rien sinon (tests)
- [x] 4. `OutputNaming` : `IMG.jpg`, puis `IMG 2.jpg`… (tests)
- [x] 5. `ImageConverter` (ImageIO) : écriture temporaire + renommage, EXIF/orientation conservés, original intact,
        échec par fichier sans arrêter les autres (tests sur une image HEIC générée)
- [ ] 6. App barre des menus : icône, menu, lancement à l'ouverture de session
- [ ] 7. Lecture de la sélection du Finder (Apple Events) + message si l'autorisation est refusée
- [ ] 8. Panneau de l'anneau R2a en SwiftUI : ouverture animée, suivi de la souris, survol, choix au relâché / au clic, Échap
- [ ] 9. Raccourci maintenu (Carbon hot key, appui + relâché), branché sur l'anneau
- [ ] 10. Bouton de souris (event tap, autorisation Accessibilité à l'activation), désactivé par défaut
- [ ] 11. Services « Convertir en JPG / PNG avec Ringlet » (secours du clic droit)
- [ ] 12. Réglages (raccourci, bouton, qualité JPG, rayon)
- [ ] 13. `scripts/build-app.sh` + `scripts/install.sh`, essai réel dans le Finder sur de vrais HEIC
- [ ] 14. Relecture complète, README final

## Revue

(à remplir à la fin)
