import Foundation

enum ShortcutAction: String, Codable, CaseIterable {
    case togglePopover = "togglePopover"
    case createStickyNote = "createStickyNote"
    case reopenLastSticky = "reopenLastSticky"
    case toggleCollapseLastSticky = "toggleCollapseLastSticky"

    var displayName: String {
        switch self {
        case .togglePopover: return "呼出白板"
        case .createStickyNote: return "新建桌面便签"
        case .reopenLastSticky: return "打开或关闭最后使用的便签"
        case .toggleCollapseLastSticky: return "展开/收起最后使用的便签"
        }
    }

    var notificationName: Notification.Name {
        switch self {
        case .togglePopover: return .toggleQuickNotePopover
        case .createStickyNote: return .createQuickNoteSticky
        case .reopenLastSticky: return .reopenLastStickyNote
        case .toggleCollapseLastSticky: return .toggleCollapseLastStickyNote
        }
    }
}

struct ShortcutConfig: Codable {
    var modifiers: UInt
    var keyCode: UInt16
}
