#!/bin/bash
# Régénère les captures du README dans docs/images, hors écran (rien ne s'affiche).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
swift build -c release --product RingletApp
.build/release/RingletApp --screenshots docs/images
echo "==> Captures dans docs/images"
