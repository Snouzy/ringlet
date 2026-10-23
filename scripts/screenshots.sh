#!/bin/bash
# Régénère les captures du README dans docs/images, hors écran (rien ne s'affiche).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
swift build -c release --product RingletApp
.build/release/RingletApp --screenshots docs/images
# Aperçu social de GitHub : 1280 × 640 (rendu en 2×).
sips -z 640 1280 docs/images/social.png >/dev/null
echo "==> Captures dans docs/images"
