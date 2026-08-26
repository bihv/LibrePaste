//
//  ClipRecord.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI

public enum ClipType: String, Codable, CaseIterable, Identifiable {
    case text
    case link
    case image
    case richtext
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .richtext: return "Rich Text"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .text: return "doc.text"
        case .link: return "link"
        case .image: return "photo"
        case .richtext: return "text.alignleft"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .text: return Color.blue
        case .link: return Color.green
        case .image: return Color.purple
        case .richtext: return Color.orange
        }
    }
}

public enum FilterType: String, CaseIterable, Identifiable {
    case all
    case text
    case link
    case image
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .link: return "Links"
        case .image: return "Images"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "doc.text"
        case .link: return "link"
        case .image: return "photo"
        }
    }
}

public struct ClipRecord: Identifiable, Codable, Equatable, Hashable {
    public var id: Int64
    public var type: ClipType
    public var content: String
    public var rtf: String?
    public var imagePath: String?
    public var preview: String
    public var hash: String
    public var pinned: Bool
    public var createdAt: Double // epoch milliseconds
    public var sourceName: String?
    public var sourceIcon: String? // app bundle identifier or path
    public var pinboardId: Int64?
    
    public init(
        id: Int64 = 0,
        type: ClipType,
        content: String,
        rtf: String? = nil,
        imagePath: String? = nil,
        preview: String,
        hash: String,
        pinned: Bool = false,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        sourceName: String? = nil,
        sourceIcon: String? = nil,
        pinboardId: Int64? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.rtf = rtf
        self.imagePath = imagePath
        self.preview = preview
        self.hash = hash
        self.pinned = pinned
        self.createdAt = createdAt
        self.sourceName = sourceName
        self.sourceIcon = sourceIcon
        self.pinboardId = pinboardId
    }
    
    public var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000.0)
    }
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    public var relativeTimeFormatted: String {
        ClipRecord.relativeDateFormatter.localizedString(for: createdDate, relativeTo: Date())
    }
}

public struct Pinboard: Identifiable, Codable, Equatable, Hashable {
    public var id: Int64
    public var name: String
    public var color: String
    public var createdAt: Double
    public var sortOrder: Int
    
    public init(
        id: Int64 = 0,
        name: String,
        color: String = "#6366f1",
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
    
    public var swiftUIColor: Color {
        Color(hex: color) ?? Color.indigo
    }
}

public struct StorageStats: Codable, Equatable {
    public var totalClips: Int
    public var pinnedClips: Int
    public var unpinnedClips: Int
    public var textClips: Int
    public var linkClips: Int
    public var imageClips: Int
    public var richTextClips: Int
    public var dbSizeBytes: Int64
    public var imagesSizeBytes: Int64
    public var totalSizeBytes: Int64
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    public var formattedDbSize: String {
        ByteCountFormatter.string(fromByteCount: dbSizeBytes, countStyle: .file)
    }
    
    public var formattedImagesSize: String {
        ByteCountFormatter.string(fromByteCount: imagesSizeBytes, countStyle: .file)
    }
}

// Extension to parse Hex color to SwiftUI Color
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
