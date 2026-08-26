//
//  FloatingPanel.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import SwiftUI

public final class FloatingPanel: NSPanel {
    public static let panelHeight: CGFloat = 360
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
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
        self.isMovable = false
        self.isMovableByWindowBackground = false
        
        // Hide on resign key
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
    }
    
    @objc private func windowDidResignKey() {
        let isAnotherAppWindowKey = NSApp.windows.contains { win in
            win != self && win.isVisible && (win.isKeyWindow || win.isMainWindow) && !(win is FloatingPanel) && !win.className.contains("StatusBar")
        }
        hidePanel(deactivateApp: !isAnotherAppWindowKey)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public func positionAtBottom(on screen: NSScreen? = NSScreen.main) {
        guard let targetScreen = screen ?? NSScreen.main else { return }
        let visibleFrame = targetScreen.visibleFrame
        let frame = NSRect(
            x: visibleFrame.origin.x,
            y: visibleFrame.origin.y,
            width: visibleFrame.size.width,
            height: FloatingPanel.panelHeight
        )
        self.setFrame(frame, display: true)
    }
    
    public func showPanel() {
        // Find screen with cursor
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let targetScreen = screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        positionAtBottom(on: targetScreen)
        
        self.alphaValue = 0
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    public func hidePanel(deactivateApp: Bool = true) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            let hasOtherVisibleWindows = NSApp.windows.contains { win in
                win != self && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
            }
            if deactivateApp && !hasOtherVisibleWindows {
                NSApp.deactivate()
            }
        })
    }
    
    public func togglePanel() {
        if self.isVisible && self.alphaValue > 0 {
            hidePanel()
        } else {
            showPanel()
        }
    }
}
