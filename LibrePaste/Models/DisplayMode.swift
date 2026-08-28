//
//  DisplayMode.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

/// Window presentation mode and anchor position
public enum WindowPresentationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottomShelf = "bottomShelf"
    case menuBarPopover = "menuBarPopover"
    case centerWindow = "centerWindow"
    case atCursor = "atCursor"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .bottomShelf:
            return "Bottom Shelf"
        case .menuBarPopover:
            return "Menu Bar Popover"
        case .centerWindow:
            return "Center Palette"
        case .atCursor:
            return "At Mouse Cursor"
        }
    }
    
    public var description: String {
        switch self {
        case .bottomShelf:
            return "Wide floating bar docked at the bottom of the screen"
        case .menuBarPopover:
            return "Compact window anchored directly below the menu bar icon"
        case .centerWindow:
            return "Spotlight-style floating palette in the center of the screen"
        case .atCursor:
            return "Floating window anchored near your mouse cursor for instant access"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .bottomShelf:
            return "dock.rectangle"
        case .menuBarPopover:
            return "menubar.arrow.down.rectangle"
        case .centerWindow:
            return "macwindow.on.rectangle"
        case .atCursor:
            return "cursorarrow.rays"
        }
    }
    
    public func targetWidth(for layout: ClipLayoutStyle) -> CGFloat {
        switch self {
        case .bottomShelf:
            return 800
        case .menuBarPopover:
            // Tăng 20% chiều rộng ở chế độ dọc: 440 -> 530pt
            return layout == .cards ? 680 : 530
        case .centerWindow:
            // Tăng 20% chiều rộng ở chế độ dọc: 540 -> 650pt
            return layout == .cards ? 720 : 650
        case .atCursor:
            // Tăng 20% chiều rộng ở chế độ dọc: 420 -> 510pt
            return layout == .cards ? 640 : 510
        }
    }
    
    public func targetHeight(for layout: ClipLayoutStyle) -> CGFloat {
        switch self {
        case .bottomShelf:
            return 360
        case .menuBarPopover:
            return layout == .cards ? 400 : 540
        case .centerWindow:
            return layout == .cards ? 440 : 560
        case .atCursor:
            return layout == .cards ? 380 : 500
        }
    }
    
    public var defaultWidth: CGFloat {
        targetWidth(for: .compactList)
    }
    
    public var defaultHeight: CGFloat {
        targetHeight(for: .compactList)
    }
}

/// Clip listing layout style
public enum ClipLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case cards = "cards"
    case compactList = "compactList"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .cards:
            return "Horizontal Cards"
        case .compactList:
            return "Vertical Compact List"
        }
    }
    
    public var description: String {
        switch self {
        case .cards:
            return "Visual card carousel with rich preview banners"
        case .compactList:
            return "Dense single-column list optimized for fast keyboard navigation"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .cards:
            return "rectangle.grid.1x2"
        case .compactList:
            return "list.bullet"
        }
    }
}
