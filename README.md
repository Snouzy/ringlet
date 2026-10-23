# Ringlet

A radial action ring for files selected in the macOS Finder. Hold a shortcut, a mouse button, or the right mouse
button, flick toward an action, release. First actions: convert HEIC photos to JPG or PNG, next to the originals.

- **Pie ring under the cursor** — pick by direction, no aiming. Release in the center to keep it open, click to choose.
- **Three ways to open it** — hold `⌃⌥ Space` (configurable), hold the right mouse button in the Finder (a quick
  right-click still shows the usual menu), or a middle / side mouse button.
- **Right-click menu too** — *Convert to JPG/PNG with Ringlet* in the Finder's Services menu.
- **Faithful conversions** — ImageIO only: photos are straightened, keep their date, camera, GPS and color profile;
  originals are never modified; a name already taken becomes `IMG 2.jpg`.
- **Local only** — no network, no dependencies. macOS 14+, Swift 6. MIT license.

## Install from source

```sh
./scripts/install.sh   # builds Ringlet.app, installs it in ~/Applications and launches it
swift test             # core tests (ring geometry, actions, naming, real HEIC conversions)
```

Permissions: **Automation › Finder** (read the selection, asked on first use) and, only for mouse triggers,
**Accessibility**. If you use several input sources, macOS already binds `⌃⌥ Space`: pick another shortcut in
Settings › Triggers.

---

**FR** — Un anneau d'actions pour les fichiers sélectionnés dans le Finder. Maintiens un raccourci, un bouton de
souris ou le clic droit, pars vers une action, relâche. Premières actions : convertir des photos HEIC en JPG ou PNG, à
côté des originaux, métadonnées conservées. Aussi dans le menu Services du clic droit. Tout reste sur ton Mac.
