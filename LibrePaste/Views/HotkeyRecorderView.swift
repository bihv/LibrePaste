//
//  HotkeyRecorderView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import Carbon
import Cocoa

public struct HotkeyRecorderView: View {
    @Binding public var shortcut: KeyboardShortcut
    public var onChange: ((KeyboardShortcut) -> Void)?
    
    @State private var isRecording: Bool = false
    @State private var isHovering: Bool = false
    @State private var eventMonitor: Any? = nil
    @State private var heldModifiers: NSEvent.ModifierFlags = []
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    
    public init(shortcut: Binding<KeyboardShortcut>, onChange: ((KeyboardShortcut) -> Void)? = nil) {
        self._shortcut = shortcut
        self.onChange = onChange
    }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                // Recording / Display Button
                Button(action: toggleRecording) {
                    HStack(spacing: 5) {
                        if isRecording {
                            recordingContent
                        } else {
                            idleContent
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(borderColor, lineWidth: isRecording ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovering = hovering
                    DispatchQueue.main.async {
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
                .help(isRecording ? "Press your shortcut keys now (Esc to cancel)" : "Click to record a new global shortcut")
                .offset(x: shakeOffset)
                
                // Reset Button (shown if current shortcut differs from default)
                if shortcut != .defaultShortcut && !isRecording {
                    Button(action: resetToDefault) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to default (⌘ Shift V)")
                    .transition(.opacity.combined(with: .scale))
                }
            }
            
            // Helper / Error text
            if isRecording {
                Text(errorMessage ?? "Press keys with ⌘, ⌥, or ⌃ (Esc to cancel)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(errorMessage != nil ? Color.red : Color.secondary)
                    .transition(.opacity)
            }
        }
        .onDisappear {
            stopRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if isRecording {
                stopRecording()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var idleContent: some View {
        HStack(spacing: 4) {
            ForEach(shortcut.modifierSymbols, id: \.self) { symbol in
                KeyCapBadge(symbol: symbol)
            }
            KeyCapBadge(symbol: shortcut.keySymbol)
        }
    }
    
    @ViewBuilder
    private var recordingContent: some View {
        let activeModifierSymbols = heldModifierSymbols
        if !activeModifierSymbols.isEmpty {
            HStack(spacing: 4) {
                ForEach(activeModifierSymbols, id: \.self) { symbol in
                    KeyCapBadge(symbol: symbol, isHighlighted: true)
                }
                Text("...")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 4)
            }
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text("Type shortcut...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
    
    private var buttonBackground: some View {
        Group {
            if isRecording {
                Color.accentColor.opacity(0.1)
            } else if isHovering {
                Color.primary.opacity(0.06)
            } else {
                Color.primary.opacity(0.03)
            }
        }
    }
    
    private var borderColor: Color {
        if isRecording {
            return Color.accentColor
        } else if isHovering {
            return Color.primary.opacity(0.2)
        } else {
            return Color.primary.opacity(0.1)
        }
    }
    
    private var heldModifierSymbols: [String] {
        var symbols: [String] = []
        if heldModifiers.contains(.control) { symbols.append("⌃") }
        if heldModifiers.contains(.option) { symbols.append("⌥") }
        if heldModifiers.contains(.shift) { symbols.append("⇧") }
        if heldModifiers.contains(.command) { symbols.append("⌘") }
        return symbols
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        errorMessage = nil
        isRecording = true
        heldModifiers = NSEvent.modifierFlags.intersection([.command, .option, .control, .shift])
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                DispatchQueue.main.async {
                    self.heldModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                }
                return nil
            }
            
            if event.type == .keyDown {
                // Cancel on Escape
                if event.keyCode == 53 {
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                    return nil
                }
                
                // Reset on Delete or Backspace
                if event.keyCode == 51 || event.keyCode == 117 {
                    DispatchQueue.main.async {
                        self.resetToDefault()
                    }
                    return nil
                }
                
                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let carbonMods = KeyboardShortcut.carbonModifiers(from: flags)
                let newShortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
                
                if newShortcut.isValid {
                    DispatchQueue.main.async {
                        self.shortcut = newShortcut
                        self.onChange?(newShortcut)
                        self.stopRecording()
                    }
                    return nil
                } else {
                    DispatchQueue.main.async {
                        self.triggerErrorFeedback(message: "Shortcut must include ⌘, ⌥, or ⌃")
                    }
                    return nil
                }
            }
            
            return event
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
        heldModifiers = []
        errorMessage = nil
    }
    
    private func resetToDefault() {
        let def = KeyboardShortcut.defaultShortcut
        shortcut = def
        onChange?(def)
        stopRecording()
    }
    
    private func triggerErrorFeedback(message: String) {
        errorMessage = message
        withAnimation(.default) {
            shakeOffset = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) {
                self.shakeOffset = 6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.default) {
                    self.shakeOffset = 0
                }
            }
        }
    }
}

// MARK: - KeyCapBadge

public struct KeyCapBadge: View {
    public let symbol: String
    public var isHighlighted: Bool = false
    
    public init(symbol: String, isHighlighted: Bool = false) {
        self.symbol = symbol
        self.isHighlighted = isHighlighted
    }
    
    public var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isHighlighted ? Color.accentColor : Color.primary)
            .padding(.horizontal, symbol.count > 1 ? 6 : 5)
            .padding(.vertical, 3)
            .frame(minWidth: 20, minHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.07), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(
                        isHighlighted ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            )
    }
}
