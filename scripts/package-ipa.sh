#!/usr/bin/env bash
#
# package-ipa.sh — build UNSIGNED IPAs for the Tetherless app and the helper mockup.
# No signing identity is needed. The app and its tunnel extension are ad-hoc signed
# with their entitlement files so the Network Extension request survives into
# whichever signer you use afterwards (re-sign with your own certificate + profile).
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="build/ipa"
DERIVED="build/DerivedData"
rm -rf "$OUT" && mkdir -p "$OUT"

build() { # scheme
  xcodebuild -project Sideloader.xcodeproj -scheme "$1" -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
}

pack() { # app-name ipa-name
  local app="$DERIVED/Build/Products/Release-iphoneos/$1.app"
  local stage="build/stage/$2"
  rm -rf "$stage" && mkdir -p "$stage/Payload"
  ditto "$app" "$stage/Payload/$1.app"
  (cd "$stage" && zip -qry "../../../$OUT/$2.ipa" Payload)
}

build Sideloader
build SideloaderHelper

# Keep entitlement requests in the binaries (extension first, then the app that embeds it).
APP="$DERIVED/Build/Products/Release-iphoneos/Sideloader.app"
for appex in "$APP"/PlugIns/*.appex; do
  codesign -f -s - --entitlements TetherlessTunnel/TetherlessTunnel.entitlements "$appex"
done
codesign -f -s - --entitlements Sideloader/Sideloader.entitlements "$APP"

pack Sideloader Tetherless
pack SideloaderHelper TetherlessDecrypt
echo "Wrote:"; ls -la "$OUT"
