#!/bin/bash
set -e

APP="Respiro.app"
BINARY="Respiro"

# Compile
swiftc -parse-as-library app.swift -o "$BINARY" -framework Cocoa -framework UserNotifications

# Create .app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mv "$BINARY" "$APP/Contents/MacOS/"

# Copy assets
cp assets/AppIcon.icns "$APP/Contents/Resources/"
cp assets/menubar_icon.png "$APP/Contents/Resources/"
cp assets/menubar_icon@2x.png "$APP/Contents/Resources/"

# Info.plist
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.waleed.respiro</string>
    <key>CFBundleName</key>
    <string>Respiro</string>
    <key>CFBundleDisplayName</key>
    <string>Respiro</string>
    <key>CFBundleExecutable</key>
    <string>Respiro</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>banner</string>
</dict>
</plist>
PLIST

# Run tests
echo "Running tests..."
swiftc -DTESTING -parse-as-library app.swift main_tests.swift -o run_tests -framework Cocoa -framework UserNotifications
./run_tests
rm -f run_tests

echo ""
echo "Built: $APP"
echo "Run:   open $APP"
