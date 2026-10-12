#!/bin/bash
# Build PeekBar.app from main.swift. No Xcode project, no dependencies.
set -euo pipefail
cd "$(dirname "$0")"

APP="PeekBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O main.swift -o "$APP/Contents/MacOS/PeekBar" \
  -framework Cocoa -framework ApplicationServices -framework Carbon -framework ServiceManagement

[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PeekBar</string>
  <key>CFBundleIdentifier</key><string>local.peekbar</string>
  <key>CFBundleExecutable</key><string>PeekBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

# Sign with the stable self-signed identity if present (keeps the Accessibility
# grant across rebuilds); otherwise fall back to ad-hoc. The identity is
# untrusted/self-signed, so we look it up in the full list and sign by hash
# (unambiguous even if duplicates ever exist).
HASH=$(security find-identity -p codesigning | grep "PeekBar Self Signed" | head -1 | awk '{print $2}')
if [ -n "$HASH" ]; then
  codesign --force --options runtime -s "$HASH" -i local.peekbar "$APP" && echo "signed with stable identity ($HASH)"
else
  codesign --force -s - "$APP" && echo "ad-hoc signed (run ./make-cert.sh for a stable identity)"
fi

# Refresh Finder/Dock icon cache for the rebuilt bundle.
touch "$APP"

echo "Built ./$APP"
echo "Run it:  open ./$APP     (or: ./$APP/Contents/MacOS/PeekBar)"
