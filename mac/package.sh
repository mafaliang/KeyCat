#!/bin/sh
# Builds the universal app and packs dist/KeyCat-macOS.zip for a GitHub release, plus
# dist/latest-mac.json, which installed copies read to update themselves (mac/Updater.swift).
# The asset names stay fixed so github.com/.../releases/latest/download/<name> keeps working.
# Usage: sh mac/package.sh
set -eu
cd "$(dirname "$0")/.."
sh mac/build.sh
rm -rf dist
mkdir -p dist
# ditto keeps the bundle's symlinks and permission bits intact; zip(1) would flatten them.
ditto -c -k --keepParent build/KeyCat.app dist/KeyCat-macOS.zip
# Hash from inside dist/ so `shasum -c KeyCat-macOS.zip.sha256` works next to the download.
(cd dist && shasum -a 256 KeyCat-macOS.zip | tee KeyCat-macOS.zip.sha256)
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' mac/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' mac/Info.plist)"
SHA="$(cut -d' ' -f1 dist/KeyCat-macOS.zip.sha256)"
cat > dist/latest-mac.json <<EOF
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "https://github.com/ElloboDK/KeyCat/releases/download/v$VERSION/KeyCat-macOS.zip",
  "sha256": "$SHA"
}
EOF
cat dist/latest-mac.json
ls -lh dist
