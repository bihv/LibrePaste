//
//  WindowDragHandle.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import AppKit
import SwiftUI

/// A native AppKit view that displays a system symbol icon and handles window dragging directly.
public final class NSWindowDragHandleView: NSView {
    public var symbolName: String
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?
    private var dragOffset: NSPoint = .zero
    
    public init(symbolName: String = "arrow.up.and.down.and.arrow.left.and.right") {
        self.symbolName = symbolName
        super.init(frame: .zero)
    }
    
    public required init?(coder: NSCoder) {
        self.symbolName = "arrow.up.and.down.and.arrow.left.and.right"
        super.init(coder: coder)
    }
    
    public override var acceptsFirstResponder: Bool {
        return false
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .cursorUpdate]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }
    
    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
    
    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        let frame = window.frame
        dragOffset = NSPoint(x: mouseLoc.x - frame.origin.x, y: mouseLoc.y - frame.origin.y)
        
        // Native macOS window dragging session
        window.performDrag(with: event)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else {
            super.mouseDragged(with: event)
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        let newOrigin = NSPoint(x: mouseLoc.x - dragOffset.x, y: mouseLoc.y - dragOffset.y)
        window.setFrameOrigin(newOrigin)
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let locInView = convert(event.locationInWindow, from: nil)
        let isInside = bounds.contains(locInView)
        if isHovered != isInside {
            isHovered = isInside
            needsDisplay = true
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background hover highlight
        if isHovered {
            let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            bgPath.fill()
        }
        
        // Draw system icon with hierarchical tinting
        let tintColor = NSColor.secondaryLabelColor.withAlphaComponent(isHovered ? 0.9 : 0.45)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            .applying(.init(hierarchicalColor: tintColor))
        
        if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Drag to move window")?.withSymbolConfiguration(config) {
            let imageSize = symbolImage.size
            let originX = (bounds.width - imageSize.width) / 2
            let originY = (bounds.height - imageSize.height) / 2
            let imageRect = NSRect(x: originX, y: originY, width: imageSize.width, height: imageSize.height)
            symbolImage.draw(in: imageRect)
        }
    }
}

/// SwiftUI wrapper for the native AppKit window drag handle using system symbols.
public struct WindowDragGripView: NSViewRepresentable {
    public let symbolName: String
    
    public init(symbolName: String = "arrow.up.and.down.and.arrow.left.and.right") {
        self.symbolName = symbolName
    }
    
    public func makeNSView(context: Context) -> NSWindowDragHandleView {
        let view = NSWindowDragHandleView(symbolName: symbolName)
        view.wantsLayer = true
        view.toolTip = "Drag to move window"
        return view
    }
    
    public func updateNSView(_ nsView: NSWindowDragHandleView, context: Context) {
        if nsView.symbolName != symbolName {
            nsView.symbolName = symbolName
            nsView.needsDisplay = true
        }
    }
}
