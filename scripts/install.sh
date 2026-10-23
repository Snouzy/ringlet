#!/bin/bash
# Construit Ringlet, l'installe dans ~/Applications, rafraîchit les Services et le lance.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
DEST="$HOME/Applications/Ringlet.app"

./scripts/build-app.sh

if pgrep -x Ringlet >/dev/null; then
  echo "==> Fermeture de Ringlet"
  osascript -e 'quit app "Ringlet"' >/dev/null 2>&1 || true
  for _ in $(seq 1 25); do pgrep -x Ringlet >/dev/null || break; sleep 0.2; done
  pkill -x Ringlet 2>/dev/null || true
fi

echo "==> Installation dans $DEST"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/Ringlet.app "$DEST"

echo "==> Services du clic droit"
/System/Library/CoreServices/pbs -update || true

echo "==> Lancement"
open "$DEST"
