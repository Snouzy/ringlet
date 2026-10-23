# Ringlet — conception

> 23 octobre 2026. App macOS open source : un anneau d'actions qui s'ouvre sous la souris et agit sur les
> fichiers sélectionnés dans le Finder. Première action : convertir un HEIC en JPG ou en PNG.
> Prototype de l'anneau validé : `prototype/anneau.html`, variante **R2a « Camembert de base »**.

## Ce que fait la v1

1. Je sélectionne un ou plusieurs fichiers dans le Finder.
2. Je maintiens le raccourci (par défaut `⌃⌥ Espace`) ou le bouton de souris choisi : l'anneau s'ouvre sous le curseur.
3. Je pars dans une direction : le secteur visé s'allume, son libellé s'affiche sous l'anneau.
4. Je relâche : l'action s'exécute sur toute la sélection. Relâché dans la zone morte : l'anneau reste ouvert,
   un clic choisit, `Échap` ou un clic hors de l'anneau ferme.
5. Les fichiers créés apparaissent à côté des originaux (`IMG_2041.jpg`, puis `IMG_2041 2.jpg` si le nom existe).
   Une notification discrète dit combien de fichiers ont été créés, ou ce qui a échoué.

Actions v1, proposées seulement si **toute** la sélection est en HEIC/HEIF :
- **JPG** — « Convertir en JPG » (qualité 0,9 par défaut, réglable)
- **PNG** — « Convertir en PNG »

Sélection sans action possible (aucun fichier, ou un type sans action) : l'anneau ne s'ouvre pas, une courte bulle
sous le curseur le dit (« Aucune action pour ces fichiers »).

Hors v1 (l'architecture doit les permettre sans refonte) : autres images (PNG → JPG, réduction), PDF, vidéo,
actions configurables par l'utilisateur.

## Déclencheurs

- **Raccourci maintenu** (par défaut) : `RegisterEventHotKey` (Carbon) donne l'appui *et* le relâché, sans autorisation.
- **Bouton de souris** (désactivé par défaut, à activer dans les réglages) : bouton central, 4 ou 5. Il faut un
  event tap actif pour avaler le clic → autorisation **Accessibilité**, demandée seulement à l'activation.
- **Clic droit, en secours** : un *Service* macOS (« Convertir en JPG avec Ringlet », « … en PNG ») déclaré dans
  l'Info.plist, visible dans le menu contextuel du Finder. Pas d'extension Finder Sync en v1 (elle impose un projet
  Xcode et ne vaut que pour des dossiers surveillés).

## Sélection du Finder

Lue au moment de l'ouverture par Apple Events (`tell application "Finder" to get selection`) → autorisation
**Automatisation › Finder**, demandée au premier usage. Si le Finder n'est pas l'app au premier plan : on lit quand
même sa sélection (le cas usuel est « je viens de cliquer un fichier dans le Finder »).

## Anneau (R2a)

- Fenêtre `NSPanel` sans bordure, transparente, non activante (ne vole pas le focus), au niveau des menus,
  couvrant l'écran du curseur le temps que l'anneau est ouvert (pour suivre la souris sans autorisation).
- Secteurs pleins de `-90°` dans le sens horaire, un par action, petit écart entre eux ; zone morte au centre ;
  étiquette du secteur visé sous l'anneau. Ouverture : chaque secteur grandit depuis le centre avec un léger décalage.
- Valeurs par défaut reprises du prototype : rayon 84 pt, ouverture 180 ms, décalage 14 ms, zone morte 16 pt.
- Choix par **direction** (angle le plus proche), pas par position exacte : on n'a pas besoin d'atteindre le secteur. Au-delà du bord de l'anneau (plus 12 pt de marge), rien n'est visé : relâcher là annule.
- Anneau recentré pour rester entier à l'écran près d'un bord ; la direction se calcule depuis son centre réel.
- Mode clair et sombre (matériau système), `Réduire les animations` respecté.

## Conversion

ImageIO seulement (aucune dépendance) : `CGImageSource` → `CGImageDestination` (`public.jpeg` / `public.png`) avec
`CGImageDestinationAddImageFromSource` : métadonnées EXIF et orientation conservées, profil couleur conservé.
Exécutée hors du fil principal, fichier écrit d'abord en temporaire dans le même dossier puis renommé (jamais de
fichier à moitié écrit). Un échec sur un fichier n'arrête pas les autres ; l'original n'est jamais modifié.

## App

- App de barre des menus (`LSUIElement`), menu : Réglages…, Lancer à l'ouverture de session, Quitter.
- Réglages : raccourci, bouton de souris (aucun / central / 4 / 5), qualité JPG, rayon de l'anneau.
- SwiftPM, macOS 14+, Swift 6, comme Portwatch : `RingletCore` (logique testable, sans AppKit) + `RingletApp`.
  Script `scripts/build-app.sh` (assemble `Ringlet.app`, signature ad hoc) et `scripts/install.sh`.
- Open source : licence MIT, README en anglais et en français (à confirmer).

## Ce qui est testé

Dans `RingletCore`, sans interface : géométrie de l'anneau (angle → secteur, zone morte, recentrage au bord),
choix des actions selon les types de la sélection, nom du fichier de sortie (collisions), conversion réelle
HEIC → JPG/PNG sur une image générée par le test (dimensions, orientation et EXIF conservés, original intact).
L'anneau et les déclencheurs se vérifient en lançant l'app.

## Limites connues

- Signature ad hoc : macOS peut redemander l'autorisation Automatisation après chaque recompilation.
  Distribution publique : signature Developer ID + notarisation (compte Apple Developer, 99 $/an) — plus tard.
- Pas de Finder Sync en v1, donc pas d'entrée de premier niveau dans le clic droit (seulement via Services).
