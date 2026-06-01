#!/bin/zsh
set -e

APP_NAME="便签 Pro"
EXEC_NAME="便签 Pro"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "🔨 Building release binary..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${EXEC_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.kuzen.quicknote</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.3</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🎨 Creating app icon..."
ICONSET="icon.iconset"
mkdir -p "${ICONSET}"

# Generate a simple note icon using sips + built-in tools
for size in 16 32 128 256 512; do
    scaled=$((size * 2))
    touch "${ICONSET}/icon_${size}x${size}.png"
    touch "${ICONSET}/icon_${size}x${size}@2x.png"
done

# Use SF Symbol as a fallback icon approach via swift script
swift <<'SWIFT_EOF'
import AppKit

let sizes = [16, 32, 128, 256, 512]
let config = NSImage.SymbolConfiguration(pointSize: 512, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.systemYellow, .systemOrange]))

for size in sizes {
    let image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)!
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: "icon.iconset/icon_\(size)x\(size).png"))
    }
    if size <= 256 {
        let scaled = size * 2
        let rep2 = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: scaled, pixelsHigh: scaled, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep2)
        image.draw(in: NSRect(x: 0, y: 0, width: scaled, height: scaled))
        NSGraphicsContext.restoreGraphicsState()
        if let data = rep2.representation(using: .png, properties: [:]) {
            try! data.write(to: URL(fileURLWithPath: "icon.iconset/icon_\(size)x\(size)@2x.png"))
        }
    }
}
SWIFT_EOF

iconutil -c icns "${ICONSET}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
rm -rf "${ICONSET}"

echo "🔏 Code signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "✅ Done! ${APP_BUNDLE} is ready."
echo ""
echo "You can now:"
echo "  open ${APP_BUNDLE}              # Run the app"
echo "  cp -r ${APP_BUNDLE} /Applications/  # Install"
