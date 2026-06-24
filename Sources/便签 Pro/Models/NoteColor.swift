import SwiftUI

enum NoteColor: String, Codable, CaseIterable {
    case auto = "auto"
    case yellow = "#FFF9C4"
    case green = "#C8E6C9"
    case blue = "#BBDEFB"
    case pink = "#F8BBD0"
    case purple = "#E1BEE7"
    case orange = "#FFE0B2"
    case white = "#FFFFFF"
    case gray = "#BDBDBD"
    case dark = "#424242"

    static var selectableColors: [NoteColor] {
        [.auto, .yellow, .green, .blue, .pink, .purple, .orange]
    }

    var swiftUIColor: Color {
        if self == .auto {
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDark ? Color(white: 0.20) : Color(white: 0.90)
        }
        return Color(hex: self.rawValue) ?? .white
    }

    var nsColor: NSColor {
        NSColor(self.swiftUIColor)
    }

    var displayName: String {
        switch self {
        case .auto:   return "跟随系统"
        case .yellow: return "黄色"
        case .green:  return "绿色"
        case .blue:   return "蓝色"
        case .pink:   return "粉色"
        case .purple: return "紫色"
        case .orange: return "橙色"
        case .white:  return "白色"
        case .gray:   return "灰色"
        case .dark:   return "深色"
        }
    }
}

func systemDefaultNoteColor() -> NoteColor {
    .auto
}
