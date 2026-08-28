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
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovable = true
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
        // Do not hide if system biometric/password authentication dialog is active
        if SecurityManager.shared.isAuthenticating {
            return
        }
        
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
    
    // MARK: - Positioning Strategies
    
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
    
    public func reposition(
        mode: WindowPresentationMode,
        layout: ClipLayoutStyle? = nil,
        statusItem: NSStatusItem? = nil,
        on screen: NSScreen? = nil,
        animated: Bool = false
    ) {
        guard let targetScreen = screen ?? currentTargetScreen() else { return }
        
        let activeLayout = layout ?? AppDelegate.shared?.store.clipLayoutStyle ?? .compactList
        var targetFrame: NSRect
        let visibleFrame = targetScreen.visibleFrame
        
        switch mode {
        case .bottomShelf:
            let height = mode.targetHeight(for: activeLayout)
            targetFrame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y,
                width: visibleFrame.size.width,
                height: height
            )
        case .menuBarPopover:
            let width = mode.targetWidth(for: activeLayout)
            let height = mode.targetHeight(for: activeLayout)
            var targetX = visibleFrame.midX - width / 2
            var targetY = visibleFrame.maxY - height - 4
            
            if let button = statusItem?.button, let buttonWindow = button.window {
                let buttonRectInScreen = buttonWindow.convertToScreen(button.bounds)
                targetX = buttonRectInScreen.midX - (width / 2)
                targetY = buttonRectInScreen.minY - height - 4
            }
            
            targetX = max(visibleFrame.minX + 8, min(targetX, visibleFrame.maxX - width - 8))
            targetY = max(visibleFrame.minY + 8, min(targetY, visibleFrame.maxY - height - 4))
            targetFrame = NSRect(x: targetX, y: targetY, width: width, height: height)
            
        case .centerWindow:
            let width = mode.targetWidth(for: activeLayout)
            let height = mode.targetHeight(for: activeLayout)
            let targetX = visibleFrame.midX - (width / 2)
            let targetY = visibleFrame.midY - (height / 2) + 30
            targetFrame = NSRect(x: targetX, y: targetY, width: width, height: height)
            
        case .atCursor:
            let width = mode.targetWidth(for: activeLayout)
            let height = mode.targetHeight(for: activeLayout)
            let mousePos = NSEvent.mouseLocation
            
            // Center horizontally on mouse, place slightly below cursor
            var targetX = mousePos.x - (width / 2)
            var targetY = mousePos.y - height - 12
            
            // If window would overflow bottom edge of screen, flip above cursor
            if targetY < visibleFrame.minY + 8 {
                targetY = mousePos.y + 16
            }
            
            // Clamp safely within visible screen bounds
            targetX = max(visibleFrame.minX + 8, min(targetX, visibleFrame.maxX - width - 8))
            targetY = max(visibleFrame.minY + 8, min(targetY, visibleFrame.maxY - height - 8))
            targetFrame = NSRect(x: targetX, y: targetY, width: width, height: height)
        }
        
        if animated && self.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(targetFrame, display: true)
            }
        } else {
            self.setFrame(targetFrame, display: true)
        }
    }
    
    private func currentTargetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }
    
    // MARK: - Presentation Lifecycle
    
    public func showPanel(
        mode: WindowPresentationMode = .bottomShelf,
        layout: ClipLayoutStyle? = nil,
        statusItem: NSStatusItem? = nil
    ) {
        let targetScreen = currentTargetScreen()
        reposition(mode: mode, layout: layout, statusItem: statusItem, on: targetScreen, animated: false)
        
        self.alphaValue = 0
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        self.makeFirstResponder(self.contentView)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NotificationCenter.default.post(name: .panelDidShow, object: nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    public func hidePanel(deactivateApp: Bool = true) {
        self.makeFirstResponder(self.contentView)
        NotificationCenter.default.post(name: .panelDidHide, object: nil)
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
    
    public func togglePanel(
        mode: WindowPresentationMode = .bottomShelf,
        layout: ClipLayoutStyle? = nil,
        statusItem: NSStatusItem? = nil
    ) {
        if self.isVisible && self.alphaValue > 0 {
            hidePanel()
        } else {
            showPanel(mode: mode, layout: layout, statusItem: statusItem)
        }
    }
}
