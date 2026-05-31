import Foundation
import SwiftUI

struct Note: Identifiable, Equatable {
    var id = UUID()
    var content: String
    var attributedData: Data?
    var createdAt: Date
    var color: NoteColor
    var isSticky: Bool
    var isArchived: Bool
    var isPinned: Bool = false
    var tags: [String]
    var position: CGPoint?
    var size: CGSize?
}

extension Note: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, attributedData, createdAt, color, isSticky, isArchived, isPinned, tags
        case positionX, positionY, width, height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        attributedData = try container.decodeIfPresent(Data.self, forKey: .attributedData)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        color = try container.decode(NoteColor.self, forKey: .color)
        isSticky = try container.decodeIfPresent(Bool.self, forKey: .isSticky) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        if let px = try container.decodeIfPresent(Double.self, forKey: .positionX),
           let py = try container.decodeIfPresent(Double.self, forKey: .positionY) {
            position = CGPoint(x: px, y: py)
        }
        if let w = try container.decodeIfPresent(Double.self, forKey: .width),
           let h = try container.decodeIfPresent(Double.self, forKey: .height) {
            size = CGSize(width: w, height: h)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(attributedData, forKey: .attributedData)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(color, forKey: .color)
        try container.encode(isSticky, forKey: .isSticky)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(tags, forKey: .tags)

        if let position = position {
            try container.encode(position.x, forKey: .positionX)
            try container.encode(position.y, forKey: .positionY)
        }
        if let size = size {
            try container.encode(size.width, forKey: .width)
            try container.encode(size.height, forKey: .height)
        }
    }
}

enum NoteColor: String, Codable, CaseIterable {
    case yellow = "#FFF9C4"
    case green = "#C8E6C9"
    case blue = "#BBDEFB"
    case pink = "#F8BBD0"
    case purple = "#E1BEE7"
    case orange = "#FFE0B2"
    case white = "#FFFFFF"
    case gray = "#BDBDBD"
    case dark = "#424242"

    var swiftUIColor: Color {
        Color(hex: self.rawValue) ?? .white
    }

    var nsColor: NSColor {
        NSColor(Color(hex: self.rawValue) ?? .white)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
