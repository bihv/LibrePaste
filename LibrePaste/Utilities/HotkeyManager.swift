//
//  HotkeyManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Carbon
import Cocoa

public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    public private(set) var currentShortcut: KeyboardShortcut = .defaultShortcut
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x42505354), id: 1) // 'BPST', 1
    
    private init() {}
    
    @discardableResult
    public func registerHotkey(shortcut: KeyboardShortcut, action: @escaping () -> Void) -> Bool {
        self.action = action
        installEventHandlerIfNeeded()
        return registerShortcutInternal(shortcut)
    }
    
    public func registerDefaultHotkey(action: @escaping () -> Void) {
        registerHotkey(shortcut: .defaultShortcut, action: action)
    }
    
    @discardableResult
    public func updateShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        guard shortcut.isValid else {
            print("[HotkeyManager] Attempted to register invalid shortcut: \(shortcut.displayString)")
            return false
        }
        installEventHandlerIfNeeded()
        return registerShortcutInternal(shortcut)
    }
    
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
            
            if status == noErr && hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    manager.action?()
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
    
    private func registerShortcutInternal(_ shortcut: KeyboardShortcut) -> Bool {
        // Unregister existing hotkey
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus == noErr {
            self.currentShortcut = shortcut
            print("[HotkeyManager] Successfully registered hotkey: \(shortcut.displayString)")
            return true
        } else {
            print("[HotkeyManager] Failed to register hotkey (\(shortcut.displayString)): status \(registerStatus)")
            return false
        }
    }
    
    public func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    deinit {
        unregisterHotkey()
    }
}
