#!/bin/sh
# Builds "Herdr Notch.app" and installs it into ~/Applications (or the folder given as the first argument).
# Needs only the Xcode command line tools: xcode-select --install
set -e
cd "$(dirname "$0")"
DEST="${1:-$HOME/Applications}"
APP="$DEST/Herdr Notch.app"

swift build -c release
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/HerdrNotch" "$APP/Contents/MacOS/HerdrNotch"
cp Support/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # fork: the app icon (Support/make-icon.swift)
# Fork: sign with $SIGN_IDENTITY, else this Mac's one "Apple Development" identity, with the hardened runtime.
# A failed signature stops the build. SIGN_IDENTITY=- gives an ad hoc build.
if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: .*\)"$/\1/p')
  n=$(printf '%s' "$SIGN_IDENTITY" | grep -c . || true)
  if [ "$n" -ne 1 ]; then echo "build.sh: found $n Apple Development identities; set SIGN_IDENTITY" >&2; exit 1; fi
fi
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"
echo "Start it with: open \"$APP\""
