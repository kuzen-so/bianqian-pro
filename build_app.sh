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

# 确保存在一个固定的自签名代码签名证书。
# ad-hoc 签名每次重新编译都会生成新的 cdhash → 系统视为「另一个程序」，
# 导致开机自启动注册（SMAppService）和辅助功能授权在每次发版后失效。
# 用同一个证书签名后，签名身份（Designated Requirement）跨版本保持不变，自启动不再失效。
ensure_signing_cert() {
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
        return 0
    fi
    echo "🔐 未找到「${CERT_NAME}」证书，正在自动创建固定的自签名证书..."
    local tmp; tmp=$(mktemp -d)
    cat > "${tmp}/openssl.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no
[ dn ]
CN = ${CERT_NAME}
[ ext ]
basicConstraints   = critical,CA:false
keyUsage           = critical,digitalSignature
extendedKeyUsage   = critical,codeSigning
CNF
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -keyout "${tmp}/key.pem" -out "${tmp}/cert.pem" \
        -config "${tmp}/openssl.cnf" >/dev/null 2>&1
    # OpenSSL 3.x 默认的 PKCS12 算法 macOS security 读不了（MAC verification failed），
    # 必须用 -legacy + SHA1/3DES，且密码不能为空，否则 import 会失败。
    local p12pass="quicknote"
    openssl pkcs12 -export -legacy -macalg sha1 \
        -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES \
        -name "${CERT_NAME}" \
        -inkey "${tmp}/key.pem" -in "${tmp}/cert.pem" \
        -out "${tmp}/identity.p12" -passout pass:"${p12pass}" >/dev/null 2>&1

    local kc="${HOME}/Library/Keychains/login.keychain-db"
    # 导入私钥+证书，并授权 codesign 无提示使用私钥
    security import "${tmp}/identity.p12" -k "${kc}" -P "${p12pass}" -A \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1
    # 信任该证书用于代码签名（首次可能弹一次钥匙串授权，输入登录密码即可）
    security add-trusted-cert -r trustRoot -p codeSign -k "${kc}" "${tmp}/cert.pem" >/dev/null 2>&1 \
        || echo "   ⚠️ 自动信任失败：请在「钥匙串访问」里把「${CERT_NAME}」设为 代码签名→始终信任"
    rm -rf "${tmp}"

    if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
        echo "   ✅ 证书「${CERT_NAME}」已创建（有效期 10 年，以后所有版本复用同一身份）"
    else
        echo "   ⚠️ 证书创建后仍不可用，本次将退回 ad-hoc 签名"
    fi
}

echo "🔏 Code signing app bundle..."
ensure_signing_cert
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "   Using certificate: ${CERT_NAME}"
    codesign --force --deep --sign "${CERT_NAME}" "${APP_BUNDLE}"
else
    echo "   ⚠️ 退回 ad-hoc 签名：开机自启动 / 辅助功能授权可能在重装后失效"
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
