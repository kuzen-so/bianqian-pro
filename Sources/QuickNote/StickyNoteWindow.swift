import SwiftUI
import AppKit
import QuartzCore

extension Notification.Name {
    static let stickyNoteDoubleClicked = Notification.Name("stickyNoteDoubleClicked")
}

class StickyNoteWindowController: NSWindowController {
    private var note: Note
    private var store: NoteStore
    private var onClose: () -> Void
    private var onCreateNew: (CGPoint) -> Void
    private var onArchive: () -> Void
    private var expandedSize: CGSize?

    init(note: Note, store: NoteStore, onClose: @escaping () -> Void, onCreateNew: @escaping (CGPoint) -> Void = { _ in }, onArchive: @escaping () -> Void = {}) {
        self.note = note
        self.store = store
        self.onClose = onClose
        self.onCreateNew = onCreateNew
        self.onArchive = onArchive

        let window = StickyNoteWindow(
            contentRect: NSRect(x: 200, y: 200, width: 500, height: 400),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        super.init(window: window)

        let hostingView = NSHostingView(rootView: StickyNoteView(
            note: note,
            store: store,
            onClose: { [weak self] in
                self?.closeSticky()
            },
            onCreateNew: { [weak self] in
                guard let self = self, let window = self.window else { return }
                self.onCreateNew(window.frame.origin)
            },
            onArchive: { [weak self] in
                self?.onArchive()
            },
            onToggleCollapse: { [weak self] collapsed in
                self?.toggleCollapse(collapsed)
            }
        ))

        window.contentView = hostingView
        window.noteId = note.id

        if let pos = note.position {
            window.setFrameOrigin(NSPoint(x: pos.x, y: pos.y))
        } else {
            let offset = CGFloat(store.notes.filter { $0.isSticky }.count) * 30
            window.setFrameOrigin(NSPoint(x: 200 + offset, y: 400 - offset))
        }

        if let size = note.size {
            window.setContentSize(NSSize(width: size.width, height: size.height))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func closeSticky() {
        savePosition()
        onClose()
        close()
    }

    func savePosition() {
        guard let window = self.window else { return }
        // 从 store 取最新 note，避免用本地旧副本覆盖已编辑的内容
        guard var updated = store.notes.first(where: { $0.id == note.id }) else { return }
        updated.position = CGPoint(x: window.frame.origin.x, y: window.frame.origin.y)
        updated.size = CGSize(width: window.frame.size.width, height: window.frame.size.height)
        store.update(updated)

        // 同步更新展开尺寸，避免折叠后再展开时尺寸回退
        if window.frame.size.height > 50 {
            expandedSize = window.frame.size
        }
    }

    private func toggleCollapse(_ collapsed: Bool) {
        guard let window = self.window else { return }
        if collapsed {
            if expandedSize == nil {
                expandedSize = window.frame.size
            }
            let collapsedHeight: CGFloat = 46
            window.setContentSize(NSSize(width: window.frame.size.width, height: collapsedHeight))
        } else {
            let height = expandedSize?.height ?? 400
            window.setContentSize(NSSize(width: window.frame.size.width, height: height))
        }
    }
}

class StickyNoteWindow: NSWindow {
    var noteId: UUID?
    private var initialDragLocation: NSPoint?
    private let titleBarHeight: CGFloat = 30

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if event.clickCount == 2, isInTitleBar(event) {
                NotificationCenter.default.post(
                    name: .stickyNoteDoubleClicked,
                    object: nil,
                    userInfo: ["noteId": noteId as Any]
                )
                return
            }
            if isInTitleBar(event) {
                initialDragLocation = NSEvent.mouseLocation
            }
        case .leftMouseDragged:
            guard let initialDragLocation = initialDragLocation else { break }
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - initialDragLocation.x
            let deltaY = currentLocation.y - initialDragLocation.y

            var newOrigin = frame.origin
            newOrigin.x += deltaX
            newOrigin.y += deltaY
            setFrameOrigin(newOrigin)

            self.initialDragLocation = currentLocation

            if let controller = windowController as? StickyNoteWindowController {
                controller.savePosition()
            }
        case .leftMouseUp:
            guard initialDragLocation != nil else { break }
            initialDragLocation = nil
            if let controller = windowController as? StickyNoteWindowController {
                controller.savePosition()
            }
        default:
            break
        }

        super.sendEvent(event)
    }

    private func isInTitleBar(_ event: NSEvent) -> Bool {
        let location = event.locationInWindow
        // 当窗口接近折叠高度时，整个窗口都视为标题栏（可拖拽/可双击展开）
        let effectiveHeight = min(frame.height, titleBarHeight)
        return location.y > frame.height - effectiveHeight
    }
}

struct StickyNoteView: View {
    @State var note: Note
    @ObservedObject var store: NoteStore
    var onClose: () -> Void
    var onCreateNew: () -> Void = {}
    var onArchive: () -> Void = {}
    var onToggleCollapse: ((Bool) -> Void)? = nil

    @State private var isHovering = false
    @State private var isCollapsed = false
    @State private var formatCommand: String? = nil
    @State private var showFormatBar = false
    @Environment(\.colorScheme) var colorScheme

    /// 解析当前便签的实际背景色。`.auto` 会跟随系统模式实时变化。
    private var resolvedNoteColor: Color {
        if note.color == .auto {
            // 浅色：稍暗的浅灰，避免融入白色背景
            // 深色：较深的灰色，避免在深色背景下刺眼
            return colorScheme == .dark ? Color(white: 0.20) : Color(white: 0.90)
        }
        return note.color.swiftUIColor
    }

    private var bgColor: Color {
        if colorScheme == .dark && (note.color == .white || note.color == .auto) {
            // 深色模式下白色 / 自动 使用深色背景，避免刺眼
            return Color(white: 0.12).opacity(0.95)
        }
        return resolvedNoteColor.opacity(0.95)
    }

    private var titleText: String {
        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        var text: String
        if let first = lines.first, !first.isEmpty {
            text = String(first)
        } else {
            text = "New Note"
        }
        if text.count > 24 {
            let index = text.index(text.startIndex, offsetBy: 24)
            text = String(text[..<index]) + "…"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if !isCollapsed {
                contentArea
                Spacer(minLength: 0)
                footerBar
            }
        }
        .onChange(of: formatCommand) { newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showFormatBar = false
                }
            }
        }
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.5),
                            .init(color: Color.white.opacity(0.04), location: 1.0),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .onReceive(NotificationCenter.default.publisher(for: .stickyNoteDoubleClicked)) { notification in
            guard let id = notification.userInfo?["noteId"] as? UUID, id == note.id else { return }
            isCollapsed.toggle()
            onToggleCollapse?(isCollapsed)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            // 左侧：关闭按钮 + 对称占位圆点
            Button(action: onClose) {
                Circle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)

            Circle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 14, height: 14)
                .opacity(isHovering ? 1 : 0)

            Spacer()

            Text(titleText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Spacer()

            // 右侧：同步到 Obsidian + 新建按钮
            Button(action: syncToObsidian) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)

            Button(action: onCreateNew) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func syncToObsidian() {
        ObsidianSyncManager.shared.syncSingleNote(note)
    }

    private var contentArea: some View {
        TransparentTextEditor(
            text: Binding(
                get: { note.content },
                set: { newValue in
                    var updated = note
                    updated.content = newValue
                    store.update(updated)
                    note = updated
                }
            ),
            attributedData: Binding(
                get: { note.attributedData },
                set: { newValue in
                    var updated = note
                    updated.attributedData = newValue
                    store.update(updated)
                    note = updated
                }
            ),
            formatCommand: $formatCommand
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFormatBar.toggle() } }) {
                Text("T")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(showFormatBar ? Color.accentColor : .secondary.opacity(0.7))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            if showFormatBar {
                HStack(spacing: 8) {
                    Button(action: { formatCommand = "bold"; withAnimation { showFormatBar = false } }) {
                        Image(systemName: "bold")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { formatCommand = "italic"; withAnimation { showFormatBar = false } }) {
                        Image(systemName: "italic")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 14)

                    Button(action: { formatCommand = "red"; withAnimation { showFormatBar = false } }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)

                    Button(action: { formatCommand = "blue"; withAnimation { showFormatBar = false } }) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)

                    Button(action: { formatCommand = "black"; withAnimation { showFormatBar = false } }) {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale))
            }

            if !showFormatBar {
                Spacer()

                Text("\(note.content.count) 字")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.5))

                Spacer()
            } else {
                Spacer()
            }

            Button(action: archiveNote) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func archiveNote() {
        ScreenConfetti.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            store.archive(note)
            onArchive()
        }
    }
}

struct TransparentTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var attributedData: Data?
    @Binding var formatCommand: String?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.verticalScroller = nil

        let textView = DraggableTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.autoresizingMask = [.width, .height]
        textView.frame = NSRect(x: 0, y: 0, width: 200, height: 200)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        if let data = attributedData,
           let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)
        } else {
            textView.string = text
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasVerticalScroller = false
        nsView.verticalScroller = nil
        guard let textView = nsView.documentView as? DraggableTextView else { return }

        if let cmd = formatCommand {
            applyFormat(cmd, to: textView)
            DispatchQueue.main.async {
                self.formatCommand = nil
            }
        }
    }

    private func applyFormat(_ cmd: String, to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()

        if range.length > 0 {
            switch cmd {
            case "bold":
                textStorage.applyFontTraits(.boldFontMask, range: range)
            case "italic":
                textStorage.applyFontTraits(.italicFontMask, range: range)
            case "red":
                textStorage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
            case "blue":
                textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
            case "black":
                textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            default:
                break
            }
        } else {
            var attrs = textView.typingAttributes
            switch cmd {
            case "bold":
                if let font = attrs[.font] as? NSFont {
                    attrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
            case "italic":
                if let font = attrs[.font] as? NSFont {
                    attrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
            case "red":
                attrs[.foregroundColor] = NSColor.systemRed
            case "blue":
                attrs[.foregroundColor] = NSColor.systemBlue
            case "black":
                attrs[.foregroundColor] = NSColor.labelColor
            default:
                break
            }
            textView.typingAttributes = attrs
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TransparentTextEditor

        init(_ parent: TransparentTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if let data = textView.textStorage?.rtf(from: NSRange(location: 0, length: textView.textStorage?.length ?? 0)) {
                parent.attributedData = data
            }
        }
    }
}

class DraggableTextView: NSTextView {
}

extension StickyNoteView {
    private func changeColor() {
        let colors = NoteColor.allCases
        if let currentIndex = colors.firstIndex(of: note.color) {
            let nextIndex = (currentIndex + 1) % colors.count
            var updated = note
            updated.color = colors[nextIndex]
            store.update(updated)
            note = updated
        }
    }
}

// MARK: - Screen Confetti

class ScreenConfetti {
    static func show() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let confettiView = ConfettiView(frame: frame)
        window.contentView = confettiView
        window.makeKeyAndOrderFront(nil)

        confettiView.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            window.orderOut(nil)
        }
    }
}

class ConfettiView: NSView {
    private var leftEmitter = CAEmitterLayer()
    private var rightEmitter = CAEmitterLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupEmitters()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupEmitters()
    }

    private func setupEmitters() {
        let height = bounds.height

        // Left emitter
        leftEmitter.emitterPosition = CGPoint(x: 0, y: height / 2)
        leftEmitter.emitterSize = CGSize(width: 10, height: height * 0.6)
        leftEmitter.emitterMode = .outline
        leftEmitter.emitterShape = .line
        leftEmitter.renderMode = .unordered
        leftEmitter.birthRate = 0

        // Right emitter
        rightEmitter.emitterPosition = CGPoint(x: bounds.width, y: height / 2)
        rightEmitter.emitterSize = CGSize(width: 10, height: height * 0.6)
        rightEmitter.emitterMode = .outline
        rightEmitter.emitterShape = .line
        rightEmitter.renderMode = .unordered
        rightEmitter.birthRate = 0

        let colors: [NSColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemYellow,
            .systemPurple, .systemOrange, .systemPink, .systemCyan, .systemMint
        ]

        leftEmitter.emitterCells = colors.map { makeCell(color: $0, direction: .right) }
        rightEmitter.emitterCells = colors.map { makeCell(color: $0, direction: .left) }

        layer?.addSublayer(leftEmitter)
        layer?.addSublayer(rightEmitter)
    }

    private func makeCell(color: NSColor, direction: Direction) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 200
        cell.lifetime = 4.0
        cell.lifetimeRange = 0.5
        cell.velocity = 600
        cell.velocityRange = 100
        // macOS CAEmitterLayer angle mapping: 0=down, π/2=right, π=up, 3π/2=left
        cell.emissionLongitude = direction == .right ? .pi / 2 : -.pi / 2
        cell.emissionRange = .pi / 12
        cell.spin = 8
        cell.spinRange = 10
        cell.scale = 0.3
        cell.scaleRange = 0.1
        cell.scaleSpeed = -0.04
        cell.alphaSpeed = -0.25
        cell.color = color.cgColor
        cell.contents = createParticleImage().cgImage(forProposedRect: nil, context: nil, hints: nil)
        return cell
    }

    private func createParticleImage() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    func start() {
        leftEmitter.birthRate = 1
        rightEmitter.birthRate = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.leftEmitter.birthRate = 0
            self.rightEmitter.birthRate = 0
        }
    }

    enum Direction {
        case left, right
    }
}
