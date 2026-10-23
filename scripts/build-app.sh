#!/bin/bash
# Compile en release et assemble build/Ringlet.app (signature ad hoc).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Compilation (release)"
# Le compilateur relève les textes à traduire ; le catalogue les reçoit (sans traduction pour les nouveaux,
# ce que signale LocalizationTests).
STRINGS=".build/localized-strings"
mkdir -p "$STRINGS"
swift build -c release -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$STRINGS"
xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata "$STRINGS"/*.stringsdata
BIN="$(swift build -c release --show-bin-path)"

APP="build/Ringlet.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/RingletApp" "$APP/Contents/MacOS/Ringlet"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Langues : anglais de base (dans le code), français dans le catalogue et dans Resources/fr.lproj.
mkdir -p "$APP/Contents/Resources/en.lproj"
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
cp Resources/fr.lproj/*.strings "$APP/Contents/Resources/fr.lproj/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>fr</string></array>
  <key>CFBundleIdentifier</key>
  <string>io.snouzy.ringlet</string>
  <key>CFBundleName</key>
  <string>Ringlet</string>
  <key>CFBundleExecutable</key>
  <string>Ringlet</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict><key>default</key><string>Convert to JPG with Ringlet</string></dict>
      <key>NSMessage</key>
      <string>convertToJPEG</string>
      <key>NSPortName</key>
      <string>Ringlet</string>
      <key>NSSendFileTypes</key>
      <array><string>public.heic</string><string>public.heif</string></array>
      <key>NSRequiredContext</key>
      <dict/>
    </dict>
    <dict>
      <key>NSMenuItem</key>
      <dict><key>default</key><string>Convert to PNG with Ringlet</string></dict>
      <key>NSMessage</key>
      <string>convertToPNG</string>
      <key>NSPortName</key>
      <string>Ringlet</string>
      <key>NSSendFileTypes</key>
      <array><string>public.heic</string><string>public.heif</string></array>
      <key>NSRequiredContext</key>
      <dict/>
    </dict>
  </array>
  <key>NSAppleEventsUsageDescription</key>
  <string>Ringlet reads the files selected in the Finder to offer the ring's actions.</string>
</dict>
</plist>
PLIST

# Signature : Developer ID si disponible (les autorisations macOS survivent alors aux recompilations),
# sinon ad hoc. Forcer une identité : SIGN_IDENTITY="…" ./scripts/build-app.sh
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)}"
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  echo "==> Signature : $IDENTITY"
  codesign --force --options runtime --timestamp --entitlements Resources/Ringlet.entitlements --sign "$IDENTITY" "$APP"
else
  echo "==> Signature ad hoc (aucun certificat Developer ID : les autorisations seront redemandées à chaque compilation)"
  codesign --force --sign - "$APP"
fi
echo "OK : $APP"
