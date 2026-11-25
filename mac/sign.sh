#!/bin/sh
# Signs $1 with a local self-signed identity kept in signing/ at the repo root (gitignored).
# Ad-hoc signatures change on every build, which makes macOS forget the Input Monitoring
# grant; a fixed certificate keeps the app's identity, so the grant survives rebuilds.
set -eu
cd "$(dirname "$0")/.."
APP="$1"
DIR="$PWD/signing"
KC="$DIR/KeyCat.keychain-db"
NAME="KeyCat Local Signing"
if [ ! -f "$KC" ]; then
    mkdir -p "$DIR"
    ( umask 077; openssl rand -hex 16 > "$DIR/password" )
    PASS="$(cat "$DIR/password")"
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$NAME" \
        -addext "basicConstraints=critical,CA:false" -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -keyout "$DIR/key.pem" -out "$DIR/cert.pem" 2>/dev/null
    openssl pkcs12 -export -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -out "$DIR/id.p12" -passout "pass:$PASS" \
        -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1
    security create-keychain -p "$PASS" "$KC"
    security set-keychain-settings "$KC"
    security import "$DIR/id.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
    security set-key-partition-list -S apple-tool:,apple: -s -k "$PASS" "$KC" >/dev/null
    rm -f "$DIR/key.pem" "$DIR/id.p12"
fi
security unlock-keychain -p "$(cat "$DIR/password")" "$KC"
HASH="$(openssl x509 -in "$DIR/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
# codesign only looks in the user's keychain search list; add ours for the duration of the signing.
ORIGINAL="$(security list-keychains -d user | sed 's/^ *"//; s/"$//')"
restore() { echo "$ORIGINAL" | tr '\n' '\0' | xargs -0 security list-keychains -d user -s; }
trap restore EXIT
echo "$ORIGINAL" | tr '\n' '\0' | xargs -0 security list-keychains -d user -s "$KC"
codesign --force --sign "$HASH" --keychain "$KC" --identifier com.local.keycat "$APP"
