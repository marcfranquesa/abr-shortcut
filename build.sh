#!/bin/sh
set -eu
cd "$(dirname "$0")"
app='build/ABR Shortcut.app'
mkdir -p "$app/Contents/MacOS"
set -- -O
if [ "${VERIFY_CYCLE:-0}" = 1 ]; then set -- "$@" -D VERIFICATION; fi
xcrun swiftc "$@" Sources/main.swift -o "$app/Contents/MacOS/ABRShortcut" -framework AppKit -framework ApplicationServices
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.marcfranquesa.abr-shortcut</string>
<key>CFBundleName</key><string>ABR Shortcut</string>
<key>CFBundleExecutable</key><string>ABRShortcut</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
identity=${SIGNING_IDENTITY:-"ABR Shortcut Local Development"}
if [ "$identity" != '-' ] && ! security find-identity -p codesigning | grep -F "\"$identity\"" >/dev/null; then
    echo "No code-signing identity '$identity'. Set SIGNING_IDENTITY to a Keychain identity name." >&2
    echo "Use SIGNING_IDENTITY=- for an ad-hoc build (Accessibility must be re-granted after changes)." >&2
    exit 1
fi
codesign --force --sign "$identity" "$app"
codesign --verify --strict "$app"
