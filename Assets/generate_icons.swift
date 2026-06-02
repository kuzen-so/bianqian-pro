import AppKit

// MARK: - App Icon Generator
func generateAppIcon(size: Int, outputPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22

    // 1. 背景：温暖的便签纸渐变
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.70, alpha: 1.0),  // 明亮暖黄
            NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.50, alpha: 1.0),  // 金黄
        ],
        atLocations: [0.0, 1.0],
        colorSpace: NSColorSpace.deviceRGB
    )!

    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient.draw(in: path, angle: -45)

    // 2. 内阴影/边框效果（让图标更有层次感）
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()

    // 顶部高光
    let highlight = NSBezierPath(roundedRect: NSRect(x: 0, y: CGFloat(size) * 0.5, width: CGFloat(size), height: CGFloat(size) * 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.white.withAlphaComponent(0.25).setFill()
    highlight.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    // 3. 底部阴影条（增加立体感）
    let shadowRect = NSRect(x: cornerRadius * 0.3, y: cornerRadius * 0.3, width: CGFloat(size) - cornerRadius * 0.6, height: CGFloat(size) * 0.06)
    let shadowPath = NSBezierPath(roundedRect: shadowRect, xRadius: shadowRect.height / 2, yRadius: shadowRect.height / 2)
    NSColor.black.withAlphaComponent(0.08).setFill()
    shadowPath.fill()

    // 4. 中央便签纸图形
    let paperSize = CGFloat(size) * 0.55
    let paperX = (CGFloat(size) - paperSize) / 2
    let paperY = (CGFloat(size) - paperSize) / 2 + CGFloat(size) * 0.02
    let paperRect = NSRect(x: paperX, y: paperY, width: paperSize, height: paperSize)
    let paperRadius = CGFloat(size) * 0.06

    // 便签纸阴影
    let paperShadow = NSShadow()
    paperShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.015)
    paperShadow.shadowBlurRadius = CGFloat(size) * 0.03
    paperShadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    paperShadow.set()

    let paperPath = NSBezierPath(roundedRect: paperRect, xRadius: paperRadius, yRadius: paperRadius)
    NSColor.white.setFill()
    paperPath.fill()
    paperShadow.set() // 重置阴影

    // 5. 便签纸上的横线（模拟笔记本）
    let lineCount = 4
    let lineSpacing = paperSize * 0.18
    let firstLineY = paperY + paperSize * 0.25
    let lineWidth = paperSize * 0.7
    let lineX = paperX + (paperSize - lineWidth) / 2

    for i in 0..<lineCount {
        let lineRect = NSRect(
            x: lineX,
            y: firstLineY + CGFloat(i) * lineSpacing,
            width: lineWidth,
            height: max(1, CGFloat(size) * 0.008)
        )
        let linePath = NSBezierPath(roundedRect: lineRect, xRadius: lineRect.height / 2, yRadius: lineRect.height / 2)
        NSColor(calibratedRed: 0.75, green: 0.70, blue: 0.50, alpha: 0.5).setFill()
        linePath.fill()
    }

    // 6. 铅笔图标
    let pencilSize = CGFloat(size) * 0.22
    let pencilX = paperX + paperSize * 0.55
    let pencilY = paperY + paperSize * 0.15
    let pencilRect = NSRect(x: pencilX, y: pencilY, width: pencilSize, height: pencilSize * 3.5)

    // 铅笔旋转 45 度
    let transform = NSAffineTransform()
    transform.translateX(by: pencilX + pencilSize / 2, yBy: pencilY + pencilSize * 3.5 / 2)
    transform.rotate(byDegrees: 45)
    transform.translateX(by: -(pencilX + pencilSize / 2), yBy: -(pencilY + pencilSize * 3.5 / 2))

    NSGraphicsContext.current?.saveGraphicsState()
    transform.concat()

    // 铅笔身
    let bodyRect = NSRect(x: pencilX + pencilSize * 0.2, y: pencilY + pencilSize * 0.8, width: pencilSize * 0.6, height: pencilSize * 2.2)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: pencilSize * 0.1, yRadius: pencilSize * 0.1)
    NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.25, alpha: 1.0).setFill()
    bodyPath.fill()

    // 铅笔笔尖（三角形）
    let tipPath = NSBezierPath()
    tipPath.move(to: NSPoint(x: pencilX + pencilSize * 0.5, y: pencilY))
    tipPath.line(to: NSPoint(x: pencilX + pencilSize * 0.2, y: pencilY + pencilSize * 0.8))
    tipPath.line(to: NSPoint(x: pencilX + pencilSize * 0.8, y: pencilY + pencilSize * 0.8))
    tipPath.close()
    NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.20, alpha: 1.0).setFill()
    tipPath.fill()

    // 铅笔笔芯
    let leadPath = NSBezierPath()
    leadPath.move(to: NSPoint(x: pencilX + pencilSize * 0.5, y: pencilY + pencilSize * 0.15))
    leadPath.line(to: NSPoint(x: pencilX + pencilSize * 0.38, y: pencilY + pencilSize * 0.5))
    leadPath.line(to: NSPoint(x: pencilX + pencilSize * 0.62, y: pencilY + pencilSize * 0.5))
    leadPath.close()
    NSColor(calibratedRed: 0.3, green: 0.2, blue: 0.15, alpha: 1.0).setFill()
    leadPath.fill()

    // 铅笔顶部橡皮
    let eraserRect = NSRect(x: pencilX + pencilSize * 0.2, y: pencilY + pencilSize * 3.0, width: pencilSize * 0.6, height: pencilSize * 0.5)
    let eraserPath = NSBezierPath(roundedRect: eraserRect, xRadius: pencilSize * 0.08, yRadius: pencilSize * 0.08)
    NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.35, alpha: 1.0).setFill()
    eraserPath.fill()

    // 金属环
    let metalRect = NSRect(x: pencilX + pencilSize * 0.15, y: pencilY + pencilSize * 2.9, width: pencilSize * 0.7, height: pencilSize * 0.12)
    let metalPath = NSBezierPath(roundedRect: metalRect, xRadius: pencilSize * 0.03, yRadius: pencilSize * 0.03)
    NSColor(calibratedRed: 0.75, green: 0.75, blue: 0.78, alpha: 1.0).setFill()
    metalPath.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    // 7. 右上角折角效果
    let foldSize = CGFloat(size) * 0.12
    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: CGFloat(size) - cornerRadius, y: CGFloat(size)))
    foldPath.line(to: NSPoint(x: CGFloat(size), y: CGFloat(size) - cornerRadius))
    foldPath.line(to: NSPoint(x: CGFloat(size), y: CGFloat(size) - cornerRadius - foldSize))
    foldPath.line(to: NSPoint(x: CGFloat(size) - cornerRadius - foldSize, y: CGFloat(size)))
    foldPath.close()

    // 折角阴影面
    let foldGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.45, alpha: 1.0),
            NSColor(calibratedRed: 0.90, green: 0.78, blue: 0.35, alpha: 1.0),
        ],
        atLocations: [0.0, 1.0],
        colorSpace: NSColorSpace.deviceRGB
    )!
    foldGradient.draw(in: foldPath, angle: 45)

    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: outputPath))
    }
}

// MARK: - Status Bar Icon Generator
func generateStatusBarIcon(size: Int, outputPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)

    // 便签纸轮廓（Template 风格，纯黑色）
    let paperW = s * 0.65
    let paperH = s * 0.75
    let paperX = (s - paperW) / 2
    let paperY = (s - paperH) / 2 + s * 0.02
    let radius = s * 0.08

    let paperPath = NSBezierPath(roundedRect: NSRect(x: paperX, y: paperY, width: paperW, height: paperH), xRadius: radius, yRadius: radius)

    // 折角
    let foldSize = s * 0.18
    paperPath.move(to: NSPoint(x: paperX + paperW - radius, y: paperY + paperH))
    paperPath.line(to: NSPoint(x: paperX + paperW, y: paperY + paperH - radius))
    paperPath.line(to: NSPoint(x: paperX + paperW, y: paperY + paperH - radius - foldSize))
    paperPath.line(to: NSPoint(x: paperX + paperW - radius - foldSize, y: paperY + paperH))
    paperPath.close()

    NSColor.black.setFill()
    paperPath.fill()

    // 内部横线（更细，代表文字）
    let lineCount = 3
    let lineSpacing = paperH * 0.16
    let firstLineY = paperY + paperH * 0.28
    let lineW = paperW * 0.55
    let lineX = paperX + (paperW - lineW) / 2 - s * 0.03
    let lineH = max(1, s * 0.04)

    for i in 0..<lineCount {
        let lineRect = NSRect(
            x: lineX,
            y: firstLineY + CGFloat(i) * lineSpacing,
            width: lineW,
            height: lineH
        )
        let linePath = NSBezierPath(roundedRect: lineRect, xRadius: lineH / 2, yRadius: lineH / 2)
        NSColor.black.setFill()
        linePath.fill()
    }

    // 小铅笔图标（右下角）
    let pencilSize = s * 0.28
    let px = paperX + paperW * 0.55
    let py = paperY + paperH * 0.08

    let pTransform = NSAffineTransform()
    pTransform.translateX(by: px + pencilSize / 2, yBy: py + pencilSize * 2.5 / 2)
    pTransform.rotate(byDegrees: 45)
    pTransform.translateX(by: -(px + pencilSize / 2), yBy: -(py + pencilSize * 2.5 / 2))

    NSGraphicsContext.current?.saveGraphicsState()
    pTransform.concat()

    let pBody = NSBezierPath(roundedRect: NSRect(x: px + pencilSize * 0.25, y: py + pencilSize * 0.7, width: pencilSize * 0.5, height: pencilSize * 1.4), xRadius: pencilSize * 0.08, yRadius: pencilSize * 0.08)
    NSColor.black.setFill()
    pBody.fill()

    let pTip = NSBezierPath()
    pTip.move(to: NSPoint(x: px + pencilSize * 0.5, y: py))
    pTip.line(to: NSPoint(x: px + pencilSize * 0.25, y: py + pencilSize * 0.7))
    pTip.line(to: NSPoint(x: px + pencilSize * 0.75, y: py + pencilSize * 0.7))
    pTip.close()
    NSColor.black.setFill()
    pTip.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: outputPath))
    }
}

// MARK: - Generate all sizes
let iconSizes = [16, 32, 128, 256, 512]
let iconsetPath = "Assets/AppIcon.iconset"

for size in iconSizes {
    generateAppIcon(size: size, outputPath: "\(iconsetPath)/icon_\(size)x\(size).png")
    if size <= 256 {
        generateAppIcon(size: size * 2, outputPath: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
    }
}

// Status bar icon sizes
let statusBarPath = "Assets/statusbar_icon.png"
generateStatusBarIcon(size: 44, outputPath: statusBarPath)

print("✅ Icons generated successfully!")
