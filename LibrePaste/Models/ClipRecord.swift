//
//  ClipRecord.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI
import AppKit
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Transferable Types and Payloads

nonisolated public struct DragItemPayload: Codable, Transferable, Sendable {
    public enum PayloadKind: String, Codable, Sendable {
        case pinboard
        case clip
    }
    
    public let app: String
    public let kind: PayloadKind
    public let id: Int64
    public let content: String?
    
    public init(kind: PayloadKind, id: Int64, content: String? = nil) {
        self.app = "LibrePaste"
        self.kind = kind
        self.id = id
        self.content = content
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        DataRepresentation(exportedContentType: .utf8PlainText) { item in
            guard item.kind == .clip, let content = item.content, !content.isEmpty else {
                throw CocoaError(.fileWriteUnknown)
            }
            return Data(content.utf8)
        }
    }
}

nonisolated public struct ClipTextDragPayload: Codable, Transferable, Sendable {
    public let app: String
    public let kind: DragItemPayload.PayloadKind
    public let id: Int64
    public let content: String
    
    public init(id: Int64, content: String) {
        self.app = "LibrePaste"
        self.kind = .clip
        self.id = id
        self.content = content
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.content)
        CodableRepresentation(contentType: .json)
    }
}

nonisolated public struct ClipImageDragPayload: Codable, Transferable, Sendable {
    public let app: String
    public let kind: DragItemPayload.PayloadKind
    public let id: Int64
    public let fileURL: URL
    
    public init(id: Int64, imagePath: String) {
        self.app = "LibrePaste"
        self.kind = .clip
        self.id = id
        self.fileURL = URL(fileURLWithPath: imagePath)
    }
    
    private nonisolated static func createDecryptedTempFile(from sourcePath: String) -> URL? {
        guard let decryptedData = ThumbnailManager.shared.loadDecryptedImageData(from: sourcePath) else {
            return nil
        }
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        
        let tempDir = ThumbnailManager.dragTempDir
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let tempURL = tempDir.appendingPathComponent("\(baseName).\(ext)")
        try? decryptedData.write(to: tempURL)
        return tempURL
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            let data = ThumbnailManager.shared.loadDecryptedImageData(from: item.fileURL.path) ?? Data()
            if item.fileURL.pathExtension.lowercased() == "png" {
                return data
            }
            if let image = NSImage(data: data),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return pngData
            }
            return data
        }
        DataRepresentation(exportedContentType: .jpeg) { item in
            let data = ThumbnailManager.shared.loadDecryptedImageData(from: item.fileURL.path) ?? Data()
            if ["jpg", "jpeg"].contains(item.fileURL.pathExtension.lowercased()) {
                return data
            }
            if let image = NSImage(data: data),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                return jpegData
            }
            return data
        }
        DataRepresentation(exportedContentType: .tiff) { item in
            let data = ThumbnailManager.shared.loadDecryptedImageData(from: item.fileURL.path) ?? Data()
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                return tiff
            }
            return data
        }
        FileRepresentation(exportedContentType: .png) { item in
            let tempURL = Self.createDecryptedTempFile(from: item.fileURL.path) ?? item.fileURL
            return SentTransferredFile(tempURL)
        }
        FileRepresentation(exportedContentType: .jpeg) { item in
            let tempURL = Self.createDecryptedTempFile(from: item.fileURL.path) ?? item.fileURL
            return SentTransferredFile(tempURL)
        }
        FileRepresentation(exportedContentType: .image) { item in
            let tempURL = Self.createDecryptedTempFile(from: item.fileURL.path) ?? item.fileURL
            return SentTransferredFile(tempURL)
        }
        ProxyRepresentation(exporting: { item -> URL in
            Self.createDecryptedTempFile(from: item.fileURL.path) ?? item.fileURL
        })
        CodableRepresentation(contentType: .json)
    }
}

extension DragItemPayload {
    @MainActor private static var cachedChangeCount: Int = -1
    @MainActor private static var cachedPayload: DragItemPayload? = nil
    
    @MainActor
    public static func currentDragPayload() -> DragItemPayload? {
        let pboard = NSPasteboard(name: .drag)
        if pboard.changeCount == cachedChangeCount {
            return cachedPayload
        }
        
        cachedChangeCount = pboard.changeCount
        guard let data = pboard.data(forType: .init("public.json")),
              let payload = try? JSONDecoder().decode(DragItemPayload.self, from: data),
              payload.app == "LibrePaste" else {
            cachedPayload = nil
            return nil
        }
        cachedPayload = payload
        return payload
    }
}

public enum ClipType: String, Codable, CaseIterable, Identifiable {
    case text
    case link
    case image
    case richtext
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .text: return L10n.tr("Text")
        case .link: return L10n.tr("Link")
        case .image: return L10n.tr("Image")
        case .richtext: return L10n.tr("Rich Text")
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
        case .all: return L10n.tr("All")
        case .text: return L10n.tr("Text")
        case .link: return L10n.tr("Links")
        case .image: return L10n.tr("Images")
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

nonisolated public struct ClipRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    public var isSensitive: Bool
    public var sensitiveType: SensitiveDataType?
    public var customRuleName: String?
    
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
        pinboardId: Int64? = nil,
        isSensitive: Bool = false,
        sensitiveType: SensitiveDataType? = nil,
        customRuleName: String? = nil
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
        self.isSensitive = isSensitive
        self.sensitiveType = sensitiveType
        self.customRuleName = customRuleName
    }
    
    public var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000.0)
    }
    
    public var relativeTimeFormatted: String {
        createdDate.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated).locale(L10n.currentLocale))
    }
}

// MARK: - ClipRecord Transferable

extension ClipRecord: @preconcurrency Transferable {
    @MainActor public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.content)
        CodableRepresentation(contentType: .json)
    }
}

nonisolated public struct Pinboard: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    
    @MainActor
    public var swiftUIColor: Color {
        Color(hex: color) ?? Color.indigo
    }
}

// MARK: - Pinboard Transferable

extension Pinboard: @preconcurrency Transferable {
    @MainActor public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
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
    nonisolated init?(hex: String) {
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
