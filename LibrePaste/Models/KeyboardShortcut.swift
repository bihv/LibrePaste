//
//  KeyboardShortcut.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import Carbon

public struct KeyboardShortcut: Codable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    
    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    public static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    
    public static let modifierKeyCodes: Set<Int> = [
        kVK_Command,
        kVK_Shift,
        kVK_Option,
        kVK_Control,
        kVK_RightShift,
        kVK_RightOption,
        kVK_RightControl,
        kVK_CapsLock,
        54, // Right Command
        63  // Function (fn)
    ]
    
    public var isValid: Bool {
        let hasPrimaryModifier = (modifiers & UInt32(cmdKey | optionKey | controlKey)) != 0
        let isModifierOnlyKey = Self.modifierKeyCodes.contains(Int(keyCode))
        return hasPrimaryModifier && !isModifierOnlyKey
    }
    
    public var modifierSymbols: [String] {
        var symbols: [String] = []
        if (modifiers & UInt32(controlKey)) != 0 { symbols.append("⌃") }
        if (modifiers & UInt32(optionKey)) != 0 { symbols.append("⌥") }
        if (modifiers & UInt32(shiftKey)) != 0 { symbols.append("⇧") }
        if (modifiers & UInt32(cmdKey)) != 0 { symbols.append("⌘") }
        return symbols
    }
    
    public var keySymbol: String {
        return Self.symbol(for: keyCode)
    }
    
    public var displayString: String {
        return (modifierSymbols + [keySymbol]).joined(separator: " ")
    }
    
    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        return carbonModifiers
    }
    
    public static func modifierFlags(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (carbonModifiers & UInt32(cmdKey)) != 0 { flags.insert(.command) }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { flags.insert(.shift) }
        if (carbonModifiers & UInt32(optionKey)) != 0 { flags.insert(.option) }
        if (carbonModifiers & UInt32(controlKey)) != 0 { flags.insert(.control) }
        return flags
    }
    
    public static func symbol(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default:
            if let translated = translateKeyCode(UInt16(keyCode)) {
                return translated
            }
            if let fallback = fallbackKeyMap[Int(keyCode)] {
                return fallback
            }
            return "Key \(keyCode)"
        }
    }
    
    private static func translateKeyCode(_ keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let cfType = unsafeBitCast(layoutDataPtr, to: AnyObject.self)
        guard CFGetTypeID(cfType) == CFDataGetTypeID() else {
            return nil
        }
        let layoutData = unsafeBitCast(cfType, to: CFData.self)
        guard let keyboardLayout = CFDataGetBytePtr(layoutData) else { return nil }
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0
        
        let result = UCKeyTranslate(
            keyboardLayout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        
        if result == noErr && length > 0 {
            let str = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
            if !str.isEmpty {
                return str.uppercased()
            }
        }
        return nil
    }
    
    private static let fallbackKeyMap: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Equal: "=", kVK_ANSI_Minus: "-", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_Quote: "'", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/",
        kVK_ANSI_Period: ".", kVK_ANSI_Grave: "`"
    ]
    
    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"keyCode\":\(keyCode),\"modifiers\":\(modifiers)}"
    }
    
    public static func from(jsonString: String?) -> KeyboardShortcut {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return .defaultShortcut
        }
        let decoder = JSONDecoder()
        if let shortcut = try? decoder.decode(KeyboardShortcut.self, from: data) {
            return shortcut
        }
        return .defaultShortcut
    }
}
