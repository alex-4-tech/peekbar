#!/bin/bash
# Create a stable self-signed code-signing identity for PeekBar and import it
# into the login keychain. A stable identity means the Accessibility grant
# survives rebuilds (TCC keys on the signing identity, not the binary hash).
# Re-running is a no-op if the identity already exists.
set -euo pipefail
cd "$(dirname "$0")"

NAME="PeekBar Self Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Note: a self-signed cert is untrusted, so it does NOT appear under
# `find-identity -v` (valid only). We check the full list instead.
if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "Identity '$NAME' already present — nothing to do."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/openssl.cnf" <<CNF
[req]
distinguished_name=dn
x509_extensions=v3
prompt=no
[dn]
CN=$NAME
[v3]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf"
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out peekbar-codesign.p12 -passout pass:peekbar -name "$NAME"

# Import (private key authorised for codesign so it won't prompt on every sign).
security import peekbar-codesign.p12 -k "$KEYCHAIN" -P peekbar -T /usr/bin/codesign

echo "Imported '$NAME' into login keychain."
security find-identity -p codesigning | grep "$NAME" \
  && echo "(Untrusted self-signed is expected — codesign uses it fine for local builds.)"
