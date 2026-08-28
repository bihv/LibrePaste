//
//  HotkeyManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Carbon
import Cocoa

public enum HotkeyIdentifier: UInt32, CaseIterable {
    case mainPanel = 1
    case pasteQueueNext = 2
    case toggleQueueHUD = 3
}

@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    private let signature: OSType = OSType(0x42505354) // 'BPST'
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]
    private var shortcuts: [UInt32: KeyboardShortcut] = [:]
    
    public var currentShortcut: KeyboardShortcut {
        return shortcuts[HotkeyIdentifier.mainPanel.rawValue] ?? .defaultShortcut
    }
    
    private init() {}
    
    // MARK: - Multi-Hotkey API
    
    @discardableResult
    public func registerHotkey(id: UInt32, shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool {
        self.actions[id] = action
        installEventHandlerIfNeeded()
        return registerShortcutInternal(id: id, shortcut: shortcut)
    }
    
    @discardableResult
    public func registerHotkey(identifier: HotkeyIdentifier, shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool {
        return registerHotkey(id: identifier.rawValue, shortcut: shortcut, action: action)
    }
    
    @discardableResult
    public func updateShortcut(id: UInt32, shortcut: KeyboardShortcut) -> Bool {
        guard shortcut.isValid else {
            print("[HotkeyManager] Attempted to register invalid shortcut (ID: \(id)): \(shortcut.displayString)")
            return false
        }
        installEventHandlerIfNeeded()
        return registerShortcutInternal(id: id, shortcut: shortcut)
    }
    
    @discardableResult
    public func updateShortcut(identifier: HotkeyIdentifier, shortcut: KeyboardShortcut) -> Bool {
        return updateShortcut(id: identifier.rawValue, shortcut: shortcut)
    }
    
    public func getShortcut(for id: UInt32) -> KeyboardShortcut? {
        return shortcuts[id]
    }
    
    public func getShortcut(for identifier: HotkeyIdentifier) -> KeyboardShortcut? {
        return shortcuts[identifier.rawValue]
    }
    
    public func unregisterHotkey(id: UInt32) {
        if let hotKeyRef = hotKeyRefs[id] {
            UnregisterEventHotKey(hotKeyRef)
            hotKeyRefs.removeValue(forKey: id)
        }
        actions.removeValue(forKey: id)
        shortcuts.removeValue(forKey: id)
    }
    
    public func unregisterHotkey(identifier: HotkeyIdentifier) {
        unregisterHotkey(id: identifier.rawValue)
    }
    
    public func unregisterAllHotkeys() {
        for (_, hotKeyRef) in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()
        shortcuts.removeAll()
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    // MARK: - Backward Compatibility API (Main Panel Hotkey)
    
    @discardableResult
    public func registerHotkey(shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool {
        return registerHotkey(identifier: .mainPanel, shortcut: shortcut, action: action)
    }
    
    public func registerDefaultHotkey(action: @escaping () -> Void) {
        registerHotkey(shortcut: .defaultShortcut, action: action)
    }
    
    @discardableResult
    public func updateShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        return updateShortcut(identifier: .mainPanel, shortcut: shortcut)
    }
    
    public func unregisterHotkey() {
        unregisterHotkey(identifier: .mainPanel)
    }
    
    // MARK: - Internal Registration & Event Handling
    
    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerCallback: EventHandlerUPP = { (_, inEvent, inUserData) -> OSStatus in
            guard let inUserData = inUserData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(inUserData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                inEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    manager.actions[id]?()
                }
            }
            return noErr
        }
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        
        if installStatus != noErr {
            print("[HotkeyManager] Failed to install event handler: \(installStatus)")
        }
    }
    
    private func registerShortcutInternal(id: UInt32, shortcut: KeyboardShortcut) -> Bool {
        // Unregister existing hotkey for this ID
        if let existingRef = hotKeyRefs[id] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: id)
        }
        
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus == noErr, let ref = hotKeyRef {
            self.hotKeyRefs[id] = ref
            self.shortcuts[id] = shortcut
            print("[HotkeyManager] Successfully registered hotkey ID \(id): \(shortcut.displayString)")
            return true
        } else {
            print("[HotkeyManager] Failed to register hotkey ID \(id) (\(shortcut.displayString)): status \(registerStatus)")
            return false
        }
    }
    
    deinit {
        for (_, hotKeyRef) in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
