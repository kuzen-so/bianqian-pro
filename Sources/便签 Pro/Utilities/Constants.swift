import Foundation

enum Constants {
    static let savedNotesKey = "quicknote.saved.notes"
    static let shortcutBindingsKey = "quicknote.shortcut.bindings"
    static let showFloatingIslandKey = "quicknote.show.floating.island"
    static let windowSnapEnabledKey = "quicknote.window.snap.enabled"

    static let appSupportDirName = "QuickNote"
    static let notesFileName = "notes.json"
    static let migrationCompletedKey = "quicknote.migration.completed"

    static let animationQuick: TimeInterval = 0.15
    static let animationMedium: TimeInterval = 0.2
    static let animationCollapseDuration: TimeInterval = 0.25
    static let saveDebounceInterval: TimeInterval = 0.5
    static let confettiDelay: TimeInterval = 0.8
    static let confettiWindowDuration: TimeInterval = 2.5

    static let stickyDefaultSize = CGSize(width: 500, height: 400)
    static let stickyMinSize = CGSize(width: 360, height: 360)
    static let stickyCollapsedHeight: CGFloat = 36

    static let popoverSize = CGSize(width: 480, height: 400)

    static let defaultStickyOrigin = CGPoint(x: 200, y: 400)
    static let stickyCascadeOffset: CGFloat = 30

    static let titleBarHeight: CGFloat = 30

    enum UI {
        static let closeButtonSize: CGFloat = 14
        static let titleMaxLength = 24
        static let cornerRadius: CGFloat = 10
    }

    // MARK: - Floating Island
    enum Island {
        static let collapsedWidth: CGFloat = 160
        static let collapsedHeight: CGFloat = 36
        static let expandedWidth: CGFloat = 680
        static let expandedHeight: CGFloat = 420
        static let topInset: CGFloat = 4
        static let animationDuration: TimeInterval = 0.3
    }
}
