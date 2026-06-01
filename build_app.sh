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
cat > /tmp/gen_icon.swift <<'SWIFT_EOF'
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
swift /tmp/gen_icon.swift

iconutil -c icns "${ICONSET}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
rm -rf "${ICONSET}"

echo "🔏 Code signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "📀 Creating DMG installer..."
DMG_NAME="便签Pro.dmg"
BACKGROUND_PNG="dmg_background.png"

rm -f "${DMG_NAME}"

# 生成背景图（上方文字提示 + 简洁背景）
cat > /tmp/gen_bg.swift <<'BG_EOF'
import AppKit

let width = 640
let height = 440
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 白色背景
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

// 上方文字
let text = "将 便签 Pro 拖动到 Applications 文件夹进行安装" as NSString
let font = NSFont.systemFont(ofSize: 18, weight: .medium)
let textColor = NSColor.darkGray
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor,
    .paragraphStyle: paragraphStyle
]
let textSize = text.size(withAttributes: attrs)
text.draw(in: NSRect(x: 0, y: height - 60, width: width, height: Int(textSize.height)), withAttributes: attrs)

// 底部小提示
let hint = "或双击 便签 Pro 直接运行" as NSString
let hintFont = NSFont.systemFont(ofSize: 13, weight: .regular)
let hintColor = NSColor.gray
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: hintFont,
    .foregroundColor: hintColor,
    .paragraphStyle: paragraphStyle
]
let hintSize = hint.size(withAttributes: hintAttrs)
hint.draw(in: NSRect(x: 0, y: 20, width: width, height: Int(hintSize.height)), withAttributes: hintAttrs)

NSGraphicsContext.restoreGraphicsState()
if let data = rep.representation(using: .png, properties: [:]) {
    try! data.write(to: URL(fileURLWithPath: "dmg_background.png"))
}
BG_EOF
swift /tmp/gen_bg.swift

# 使用 create-dmg 构建安装包
# 图标大小 128px，Applications 和应用图标一样大
create-dmg \
  --volname "便签 Pro Installer" \
  --background "${BACKGROUND_PNG}" \
  --window-pos 200 120 \
  --window-size 640 440 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 160 240 \
  --app-drop-link 480 240 \
  --no-internet-enable \
  "${DMG_NAME}" \
  "${APP_BUNDLE}"

rm -f "${BACKGROUND_PNG}"

echo "✅ Done!"
echo ""
echo "Build outputs:"
echo "  ${APP_BUNDLE}     # App bundle"
echo "  ${DMG_NAME}       # DMG installer"
echo ""
echo "Install:"
echo "  open ${DMG_NAME}              # Mount and drag to Applications"
echo "  cp -r ${APP_BUNDLE} /Applications/  # Direct install"
