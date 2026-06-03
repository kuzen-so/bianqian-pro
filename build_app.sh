#!/bin/zsh
set -e

APP_NAME="便签 Pro"
EXEC_NAME="便签 Pro"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CERT_NAME="QuickNote Dev"  # 如果要固定签名保留权限，在 Keychain Access 创建同名证书

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.kuzen.quicknote</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>12</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🎨 Copying icons..."
cp "Assets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "Assets/statusbar_icon.png" "${APP_BUNDLE}/Contents/Resources/statusbar_icon.png"

echo "🔏 Code signing app bundle..."
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "   Using certificate: ${CERT_NAME}"
    codesign --force --deep --sign "${CERT_NAME}" "${APP_BUNDLE}" 2>/dev/null || true
else
    echo "   No '${CERT_NAME}' certificate found, using ad-hoc signing."
    echo "   (辅助功能权限可能需要重新授权)"
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "📀 Creating DMG installer..."
DMG_NAME="便签Pro.dmg"
BACKGROUND_PNG="dmg_background.png"

rm -f "${DMG_NAME}"

# 生成背景图
cat > /tmp/gen_bg.swift <<'BG_EOF'
import AppKit

let width = 640
let height = 440
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

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

echo ""
echo "✅ Build complete!"
echo ""
echo "Outputs:"
echo "  ${APP_BUNDLE}     # App bundle"
echo "  ${DMG_NAME}       # DMG installer"
echo ""

# 自动安装覆盖
if [ -d "/Applications/${APP_NAME}.app" ]; then
    echo "🚀 Installing to /Applications (will replace existing)..."
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 0.5
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_NAME}.app" "/Applications/"
    echo "✅ Installed to /Applications/${APP_NAME}.app"
    echo ""
    if [[ -t 0 ]]; then
        read -q "REPLY?🚀 Launch now? [y/N] "
        echo ""
        if [[ "$REPLY" == "y" ]]; then
            open "/Applications/${APP_NAME}.app"
        fi
    else
        echo "💡 Launch: open \"/Applications/${APP_NAME}.app\""
    fi
else
    echo "💡 First install:"
    echo "  cp -r '${APP_NAME}.app' /Applications/"
fi

echo ""
