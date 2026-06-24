import SwiftUI
import AppKit

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
