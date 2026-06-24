import SwiftUI
import AppKit

struct NoScrollbarScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScroller = nil
        scrollView.horizontalScroller = nil
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        scrollView.documentView = hostingView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasVerticalScroller = false
        nsView.verticalScroller = nil

        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content

            let width = nsView.contentView.bounds.width
            let size = hostingView.fittingSize
            let height = max(size.height, nsView.contentView.bounds.height)
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
    }
}
