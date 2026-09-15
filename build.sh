#!/bin/sh
set -eu
cd "$(dirname "$0")"
app='build/ABR Shortcut.app'
mkdir -p "$app/Contents/MacOS"
xcrun swiftc -O Sources/main.swift -o "$app/Contents/MacOS/ABRShortcut" -framework AppKit -framework ApplicationServices
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
codesign --force --sign - "$app"
