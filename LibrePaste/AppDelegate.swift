//
//  AppDelegate.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    public let store = ClipboardStore()
    
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var currentPreviewClip: ClipRecord?
    private var shouldRestoreFloatingPanelOnClosePreview: Bool = false
    private var editWindow: NSWindow?
    private var currentEditClip: ClipRecord?
    private var shouldRestoreFloatingPanelOnCloseEdit: Bool = false
    private var isSettingsWindowOpen: Bool = false
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Setup Dock Icon & activation policy
        updateDockVisibility()
        
        // Start watching clipboard
        ClipboardWatcher.shared.start()
        
        // Setup Status Bar Menu Item
        setupStatusItem()
        
        // Setup Floating Panel
        setupFloatingPanel()
        
        // Setup Hotkey
        let savedHotkeyJson = DatabaseManager.shared.getSetting("globalHotkey")
        let initialShortcut = KeyboardShortcut.from(jsonString: savedHotkeyJson)
        HotkeyManager.shared.registerHotkey(shortcut: initialShortcut) { [weak self] in
            self?.toggleFloatingPanel()
        }
        
        // Setup Paste Queue Hotkeys
        let savedQueueNextHotkey = DatabaseManager.shared.getSetting("pasteQueueNextHotkey")
        let queueNextShortcut = (savedQueueNextHotkey != nil && !savedQueueNextHotkey!.isEmpty)
            ? KeyboardShortcut.from(jsonString: savedQueueNextHotkey)
            : KeyboardShortcut.defaultPasteQueueNextShortcut
        HotkeyManager.shared.registerHotkey(identifier: .pasteQueueNext, shortcut: queueNextShortcut) {
            PasteQueueManager.shared.pasteNext()
        }
        
        let savedQueueHudHotkey = DatabaseManager.shared.getSetting("toggleQueueHUDHotkey")
        let queueHudShortcut = (savedQueueHudHotkey != nil && !savedQueueHudHotkey!.isEmpty)
            ? KeyboardShortcut.from(jsonString: savedQueueHudHotkey)
            : KeyboardShortcut.defaultToggleQueueHUDShortcut
        HotkeyManager.shared.registerHotkey(identifier: .toggleQueueHUD, shortcut: queueHudShortcut) {
            PasteQueueManager.shared.toggleHUD()
        }
        
        // Setup PasteQueueManager
        PasteQueueManager.shared.setup()
        
        // Register notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideFloatingPanel),
            name: .hideFloatingPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowFloatingPanel),
            name: .showFloatingPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleFloatingPanel),
            name: .toggleFloatingPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsWindow),
            name: .openSettingsWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPreviewWindow(_:)),
            name: .openPreviewWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePreviewWindow),
            name: .closePreviewWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenEditWindow(_:)),
            name: .openEditWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseEditWindow),
            name: .closeEditWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidLock),
            name: .appDidLock,
            object: nil
        )
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        ClipboardWatcher.shared.stop()
        HotkeyManager.shared.unregisterHotkey()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isSettingsWindowOpen, let win = settingsWindow {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return true
        }
        
        if let win = previewWindow, win.isVisible || win.isMiniaturized {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return true
        }
        
        if let win = editWindow, win.isVisible || win.isMiniaturized {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return true
        }
        
        toggleFloatingPanel()
        return true
    }
    
    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show LibrePaste (⌘⇧V)", action: #selector(toggleFloatingPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(handleOpenSettingsWindow), keyEquivalent: ","))
        return menu
    }
    
    public func updateDockVisibility(show: Bool? = nil) {
        let userPrefersDock = (store.settings["showInDock"] ?? "true") == "true"
        let isSettingsOpen = isSettingsWindowOpen
        
        let shouldShow: Bool
        if let explicitShow = show {
            shouldShow = explicitShow || isSettingsOpen
        } else {
            shouldShow = userPrefersDock || isSettingsOpen
        }
        
        if shouldShow {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            if let icon = NSImage(named: "AppIcon") ?? NSImage(named: "AppLogo") {
                NSApp.applicationIconImage = icon
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    // MARK: - Status Bar Item
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "LibrePaste")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "📋"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show LibrePaste (⌘⇧V)", action: #selector(toggleFloatingPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste Next from Queue (⌥⌘V)", action: #selector(pasteNextFromQueue), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Queue HUD (⌥⇧Q)", action: #selector(toggleQueueHUD), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let pauseItem = NSMenuItem(title: "Pause Watcher", action: #selector(togglePauseWatcher), keyEquivalent: "")
        menu.addItem(pauseItem)
        
        let lockItem = NSMenuItem(title: "Lock LibrePaste", action: #selector(lockAppNow), keyEquivalent: "")
        menu.addItem(lockItem)
        
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(handleOpenSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit LibrePaste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func pasteNextFromQueue() {
        SecurityManager.shared.checkLockOnReveal()
        if store.isLocked {
            toggleFloatingPanel()
            return
        }
        PasteQueueManager.shared.pasteNext()
    }
    
    @objc private func toggleQueueHUD() {
        SecurityManager.shared.checkLockOnReveal()
        if store.isLocked {
            toggleFloatingPanel()
            return
        }
        PasteQueueManager.shared.toggleHUD()
    }
    
    @objc private func togglePauseWatcher() {
        SecurityManager.shared.checkLockOnReveal()
        if store.isLocked {
            toggleFloatingPanel()
            return
        }
        store.togglePause()
    }
    
    @objc private func lockAppNow() {
        store.lockAppNow()
    }
    
    @objc private func handleAppDidLock() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let win = self.settingsWindow, win.isVisible {
                win.orderOut(nil)
            }
            if let win = self.previewWindow, win.isVisible {
                win.orderOut(nil)
            }
            if let win = self.editWindow, win.isVisible {
                win.orderOut(nil)
            }
            PasteQueueManager.shared.hideHUD()
        }
    }
    
    // MARK: - Floating Panel
    
    private func setupFloatingPanel() {
        let initialRect = NSRect(x: 0, y: 0, width: 800, height: FloatingPanel.panelHeight)
        let panel = FloatingPanel(contentRect: initialRect)
        
        let hostingView = NSHostingView(rootView: ClipboardView(store: store))
        panel.contentView = hostingView
        self.floatingPanel = panel
    }
    
    @objc public func toggleFloatingPanel() {
        guard let panel = floatingPanel else { return }
        
        if panel.isVisible && panel.alphaValue > 0 {
            panel.hidePanel()
        } else {
            // Check if timeout has expired and app should be locked
            SecurityManager.shared.checkLockOnReveal()
            
            // Remember the currently active application so we can paste into it later
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
                store.lastActiveAppBundleId = frontmost.bundleIdentifier
            }
            
            store.query = ""
            store.filter = .all
            store.activeIndex = 0
            store.isSearchFocused = false
            store.reloadClips()
            
            panel.showPanel()
        }
    }
    
    @objc private func handleHideFloatingPanel() {
        floatingPanel?.hidePanel()
    }
    
    @objc private func handleShowFloatingPanel() {
        SecurityManager.shared.checkLockOnReveal()
        floatingPanel?.showPanel()
    }
    
    @objc private func handleToggleFloatingPanel() {
        toggleFloatingPanel()
    }
    
    // MARK: - Settings Window
    
    @objc public func handleOpenSettingsWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            SecurityManager.shared.checkLockOnReveal()
            self.floatingPanel?.hidePanel(deactivateApp: false)
            self.isSettingsWindowOpen = true
            self.updateDockVisibility()
            
            if let win = self.settingsWindow {
                if win.isMiniaturized {
                    win.deminiaturize(nil)
                }
                win.orderFrontRegardless()
                win.makeKeyAndOrderFront(nil)
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: win)
                return
            }
            
            let settingsView = SettingsView(store: self.store)
            let hostingView = NSHostingView(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 490),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.toolbarStyle = .preference
            window.titlebarSeparatorStyle = .line
            SettingsWindowController.shared.setupToolbar(for: window)
            
            window.center()
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.delegate = self
            
            self.settingsWindow = window
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
    }
    
    // MARK: - Preview Window
    
    @objc public func handleOpenPreviewWindow(_ notification: Notification) {
        guard let clip = notification.object as? ClipRecord else { return }
        openPreviewWindow(clip: clip)
    }
    
    @objc public func handleClosePreviewWindow() {
        closePreviewWindow()
    }
    
    public func openPreviewWindow(clip: ClipRecord) {
        if store.isLocked {
            toggleFloatingPanel()
            return
        }
        
        // Toggle close if already open with the same clip
        if let win = previewWindow, win.isVisible, let current = currentPreviewClip, current.id == clip.id {
            closePreviewWindow()
            return
        }
        
        let wasPanelVisible = (floatingPanel?.isVisible == true && (floatingPanel?.alphaValue ?? 0) > 0)
        shouldRestoreFloatingPanelOnClosePreview = wasPanelVisible
        if wasPanelVisible {
            floatingPanel?.hidePanel(deactivateApp: false)
        }
        
        currentPreviewClip = clip
        
        let previewView = QuickLookPreviewView(
            clip: clip,
            onPaste: { [weak self] in
                guard let self = self else { return }
                self.shouldRestoreFloatingPanelOnClosePreview = false
                self.currentPreviewClip = nil
                self.previewWindow?.orderOut(nil)
                self.store.paste(clip: clip)
            },
            onClose: { [weak self] in
                self?.closePreviewWindow()
            }
        )
        
        let hostingView = NSHostingView(rootView: previewView)
        
        if let window = previewWindow {
            window.title = "LibrePaste Preview - \(clip.type.displayName)"
            window.contentView = hostingView
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LibrePaste Preview - \(clip.type.displayName)"
        window.minSize = NSSize(width: 500, height: 380)
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        self.previewWindow = window
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    }
    
    public func closePreviewWindow() {
        currentPreviewClip = nil
        previewWindow?.orderOut(nil)
        
        if shouldRestoreFloatingPanelOnClosePreview {
            shouldRestoreFloatingPanelOnClosePreview = false
            floatingPanel?.showPanel()
        } else {
            let hasOtherVisibleWindows = NSApp.windows.contains { win in
                win != self.previewWindow && win != self.editWindow && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
            }
            if !hasOtherVisibleWindows {
                NSApp.deactivate()
            }
        }
    }
    
    @objc public func handleOpenEditWindow(_ notification: Notification) {
        guard let clip = notification.object as? ClipRecord else { return }
        openEditWindow(clip: clip)
    }
    
    @objc public func handleCloseEditWindow() {
        closeEditWindow()
    }
    
    public func openEditWindow(clip: ClipRecord) {
        if store.isLocked {
            toggleFloatingPanel()
            return
        }
        
        // Bring to front if already open with the same clip
        if let win = editWindow, win.isVisible, let current = currentEditClip, current.id == clip.id {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return
        }
        
        let wasPanelVisible = (floatingPanel?.isVisible == true && (floatingPanel?.alphaValue ?? 0) > 0)
        shouldRestoreFloatingPanelOnCloseEdit = wasPanelVisible
        if wasPanelVisible {
            floatingPanel?.hidePanel(deactivateApp: false)
        }
        
        currentEditClip = clip
        
        let editView = EditClipView(
            clip: clip,
            onSave: { [weak self] newContent, newPreview, newRtf in
                guard let self = self else { return }
                self.store.updateClip(id: clip.id, content: newContent, preview: newPreview, rtf: newRtf)
                self.closeEditWindow()
            },
            onCancel: { [weak self] in
                self?.closeEditWindow()
            }
        )
        
        let hostingView = NSHostingView(rootView: editView)
        
        if let window = editWindow {
            window.title = "LibrePaste Edit - \(clip.type.displayName)"
            window.contentView = hostingView
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LibrePaste Edit - \(clip.type.displayName)"
        window.minSize = NSSize(width: 500, height: 380)
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        self.editWindow = window
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    }
    
    public func closeEditWindow() {
        currentEditClip = nil
        editWindow?.orderOut(nil)
        
        if shouldRestoreFloatingPanelOnCloseEdit {
            shouldRestoreFloatingPanelOnCloseEdit = false
            floatingPanel?.showPanel()
        } else {
            let hasOtherVisibleWindows = NSApp.windows.contains { win in
                win != self.previewWindow && win != self.editWindow && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
            }
            if !hasOtherVisibleWindows {
                NSApp.deactivate()
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == previewWindow {
            currentPreviewClip = nil
            if shouldRestoreFloatingPanelOnClosePreview {
                shouldRestoreFloatingPanelOnClosePreview = false
                floatingPanel?.showPanel()
            } else {
                let hasOtherVisibleWindows = NSApp.windows.contains { win in
                    win != window && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
                }
                if !hasOtherVisibleWindows {
                    NSApp.deactivate()
                }
            }
        } else if window == editWindow {
            currentEditClip = nil
            if shouldRestoreFloatingPanelOnCloseEdit {
                shouldRestoreFloatingPanelOnCloseEdit = false
                floatingPanel?.showPanel()
            } else {
                let hasOtherVisibleWindows = NSApp.windows.contains { win in
                    win != window && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
                }
                if !hasOtherVisibleWindows {
                    NSApp.deactivate()
                }
            }
        } else if window == settingsWindow {
            isSettingsWindowOpen = false
            updateDockVisibility()
            
            let hasOtherVisibleWindows = NSApp.windows.contains { win in
                win != window && win.isVisible && !(win is FloatingPanel) && !win.className.contains("StatusBar")
            }
            if !hasOtherVisibleWindows {
                NSApp.deactivate()
            }
        }
    }
}
