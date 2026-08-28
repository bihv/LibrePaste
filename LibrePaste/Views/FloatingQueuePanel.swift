//
//  FloatingQueuePanel.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import SwiftUI

public final class FloatingQueuePanel: NSPanel {
    public static let defaultWidth: CGFloat = 340
    public static let defaultHeight: CGFloat = 215
    
    public init() {
        let initialRect = NSRect(x: 0, y: 0, width: FloatingQueuePanel.defaultWidth, height: FloatingQueuePanel.defaultHeight)
        super.init(
            contentRect: initialRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
    }
    
    public override var canBecomeKey: Bool {
        // Return false so clicking buttons on the HUD doesn't take focus away from target app
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public func positionInCorner(on screen: NSScreen? = NSScreen.main) {
        guard let targetScreen = screen ?? NSScreen.main else { return }
        let visibleFrame = targetScreen.visibleFrame
        
        // Position at bottom-right corner with 24pt margin above Dock/screen edge
        let x = visibleFrame.maxX - FloatingQueuePanel.defaultWidth - 24
        let y = visibleFrame.minY + 24
        
        let frame = NSRect(
            x: x,
            y: y,
            width: FloatingQueuePanel.defaultWidth,
            height: FloatingQueuePanel.defaultHeight
        )
        self.setFrame(frame, display: true)
    }
    
    public func showPanel() {
        if self.frame.origin == .zero || self.frame.width == 0 {
            // Find screen with cursor
            let mouseLocation = NSEvent.mouseLocation
            let screens = NSScreen.screens
            let targetScreen = screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
            positionInCorner(on: targetScreen)
        }
        
        self.alphaValue = 0
        self.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    public func hidePanel() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
