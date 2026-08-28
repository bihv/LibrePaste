//
//  GeneralSettingsTab.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import ServiceManagement
import Combine

public struct GeneralSettingsTab: View {
    @Bindable public var store: ClipboardStore
    
    @State private var launchAtLogin: Bool = false
    @State private var showInDock: Bool = true
    @State private var windowPresentationMode: WindowPresentationMode = .bottomShelf
    @State private var clipLayoutStyle: ClipLayoutStyle = .cards
    @State private var compactShowAppIcons: Bool = true
    @State private var compactShowShortcuts: Bool = true
    @State private var compactPreviewLines: Int = 2
    @State private var pasteTarget: String = "direct"
    @State private var hideAfterPaste: Bool = true
    @State private var isAccessibilityEnabled: Bool = PasteSimulator.isAccessibilityGranted()
    @State private var currentShortcut: KeyboardShortcut = .defaultShortcut
    @State private var pasteQueueNextShortcut: KeyboardShortcut = .defaultPasteQueueNextShortcut
    @State private var toggleQueueHUDShortcut: KeyboardShortcut = .defaultToggleQueueHUDShortcut
    @State private var pasteQueueOrder: String = "fifo"
    @State private var pasteQueueRemoveAfterPaste: Bool = true
    @State private var pasteQueueAutoHide: Bool = true
    @State private var playSoundOnPaste: Bool = true
    @State private var pasteSoundName: String = "Tink"
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
            Section("Interface & Appearance") {
                Picker("Window Presentation", selection: $windowPresentationMode) {
                    ForEach(WindowPresentationMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: windowPresentationMode) { _, val in
                    store.setWindowPresentationMode(val)
                }
                
                Picker("Default Clip Layout", selection: $clipLayoutStyle) {
                    ForEach(ClipLayoutStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.systemImage).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: clipLayoutStyle) { _, val in
                    store.setClipLayoutStyle(val)
                }
                
                Toggle("Show App Icons in Compact List", isOn: $compactShowAppIcons)
                    .onChange(of: compactShowAppIcons) { _, val in
                        store.compactShowAppIcons = val
                        store.saveSetting(key: "compactShowAppIcons", value: val ? "true" : "false")
                    }
                
                Toggle("Show Number Shortcut Badges (1-9)", isOn: $compactShowShortcuts)
                    .onChange(of: compactShowShortcuts) { _, val in
                        store.compactShowShortcuts = val
                        store.saveSetting(key: "compactShowShortcuts", value: val ? "true" : "false")
                    }
                
                Picker("Preview Lines in Compact List", selection: $compactPreviewLines) {
                    Text("1 Line (Ultra Dense)").tag(1)
                    Text("2 Lines (Standard)").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: compactPreviewLines) { _, val in
                    store.compactPreviewLines = val
                    store.saveSetting(key: "compactPreviewLines", value: "\(val)")
                }
            }
            
            Section("Startup & Shortcuts") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                Toggle("Show Icon in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        store.saveSetting(key: "showInDock", value: newValue ? "true" : "false")
                        AppDelegate.shared?.updateDockVisibility(show: newValue)
                    }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Hotkey")
                        Text("Shortcut to open LibrePaste from anywhere")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView(shortcut: $currentShortcut) { newShortcut in
                        store.saveSetting(key: "globalHotkey", value: newShortcut.toJsonString())
                        HotkeyManager.shared.updateShortcut(newShortcut)
                    }
                }
            }
            
            Section("Paste Behavior") {
                Picker("Paste Mode", selection: $pasteTarget) {
                    Text("Direct Paste into Active App").tag("direct")
                    Text("Copy to Clipboard Only").tag("clipboard")
                }
                .pickerStyle(.menu)
                .onChange(of: pasteTarget) { _, val in
                    store.saveSetting(key: "pasteTarget", value: val)
                }
                
                Toggle("Hide LibrePaste window after pasting", isOn: $hideAfterPaste)
                    .onChange(of: hideAfterPaste) { _, val in
                        store.saveSetting(key: "hideAfterPaste", value: val ? "true" : "false")
                    }
                
                Toggle("Play sound when pasting", isOn: $playSoundOnPaste)
                    .onChange(of: playSoundOnPaste) { _, val in
                        store.saveSetting(key: "playSoundOnPaste", value: val ? "true" : "false")
                        PasteSimulator.shared.invalidateSoundCache()
                    }
                
                if playSoundOnPaste {
                    HStack {
                        Picker("Paste Sound", selection: $pasteSoundName) {
                            Text("Tink (Subtle Tap)").tag("Tink")
                            Text("Pop (Soft Bubble)").tag("Pop")
                            Text("Bottle (Cork Pop)").tag("Bottle")
                            Text("Glass (Crisp Chime)").tag("Glass")
                            Text("Blow (Air Puff)").tag("Blow")
                            Text("Ping (Bell)").tag("Ping")
                            Text("Purr (Soft)").tag("Purr")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: pasteSoundName) { _, val in
                            store.saveSetting(key: "pasteSoundName", value: val)
                            PasteSimulator.shared.invalidateSoundCache()
                            if let sound = NSSound(named: val) {
                                sound.volume = 0.5
                                sound.play()
                            }
                        }
                        
                        Button(action: {
                            if let sound = NSSound(named: pasteSoundName) {
                                sound.volume = 0.5
                                sound.play()
                            }
                        }) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Preview selected sound")
                    }
                }
            }
            
            Section("Paste Queue / Sequential Paste") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paste Next Shortcut")
                        Text("Paste the next queued item into the active app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView(
                        shortcut: $pasteQueueNextShortcut,
                        defaultShortcut: .defaultPasteQueueNextShortcut
                    ) { newShortcut in
                        store.saveSetting(key: "pasteQueueNextHotkey", value: newShortcut.toJsonString())
                        HotkeyManager.shared.updateShortcut(identifier: .pasteQueueNext, shortcut: newShortcut)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toggle Queue HUD")
                        Text("Show or hide the floating mini queue overlay")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView(
                        shortcut: $toggleQueueHUDShortcut,
                        defaultShortcut: .defaultToggleQueueHUDShortcut
                    ) { newShortcut in
                        store.saveSetting(key: "toggleQueueHUDHotkey", value: newShortcut.toJsonString())
                        HotkeyManager.shared.updateShortcut(identifier: .toggleQueueHUD, shortcut: newShortcut)
                    }
                }
                
                Picker("Queue Order", selection: $pasteQueueOrder) {
                    ForEach(PasteQueueOrder.allCases) { orderOption in
                        Text(orderOption.displayName).tag(orderOption.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: pasteQueueOrder) { _, val in
                    store.saveSetting(key: "pasteQueueOrder", value: val)
                    PasteQueueManager.shared.order = (val == "lifo") ? .lifo : .fifo
                }
                
                Toggle("Remove item after paste", isOn: $pasteQueueRemoveAfterPaste)
                    .onChange(of: pasteQueueRemoveAfterPaste) { _, val in
                        let behaviorStr = val ? "removeAfterPaste" : "cycle"
                        store.saveSetting(key: "pasteQueueBehavior", value: behaviorStr)
                        PasteQueueManager.shared.behavior = val ? .removeAfterPaste : .cycle
                    }
                
                Toggle("Auto-hide HUD when queue is empty", isOn: $pasteQueueAutoHide)
                    .onChange(of: pasteQueueAutoHide) { _, val in
                        store.saveSetting(key: "pasteQueueAutoHide", value: val ? "true" : "false")
                        PasteQueueManager.shared.autoHideWhenEmpty = val
                    }
            }
            
            Section("Accessibility Permissions") {
                if isAccessibilityEnabled {
                    accessibilityGrantedView
                } else {
                    accessibilityNeededView
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .onAppear {
            loadSettings()
            checkAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            checkAccessibilityStatus()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if !isAccessibilityEnabled {
                checkAccessibilityStatus()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var accessibilityGrantedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 22))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Accessibility Permission Granted")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    Text("LibrePaste has full access to simulate ⌘V and paste directly into active apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var accessibilityNeededView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18))
                Text("Accessibility Permission Needed")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Text("LibrePaste requires Accessibility permission to automatically simulate ⌘V and paste directly into other applications.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("Grant Accessibility Access") {
                PasteSimulator.requestAccessibilityPermissions()
                checkAccessibilityStatus()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)
            
            Text("After enabling LibrePaste in System Settings, quit and relaunch the app.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func loadSettings() {
        windowPresentationMode = store.windowPresentationMode
        clipLayoutStyle = store.clipLayoutStyle
        compactShowAppIcons = store.compactShowAppIcons
        compactShowShortcuts = store.compactShowShortcuts
        compactPreviewLines = store.compactPreviewLines
        
        let savedTarget = store.settings["pasteTarget"] ?? "direct"
        pasteTarget = (savedTarget == "clipboard") ? "clipboard" : "direct"
        showInDock = (store.settings["showInDock"] ?? "true") == "true"
        hideAfterPaste = (store.settings["hideAfterPaste"] ?? "true") == "true"
        
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        
        currentShortcut = KeyboardShortcut.from(jsonString: store.settings["globalHotkey"], default: .defaultShortcut)
        pasteQueueNextShortcut = KeyboardShortcut.from(jsonString: store.settings["pasteQueueNextHotkey"], default: .defaultPasteQueueNextShortcut)
        toggleQueueHUDShortcut = KeyboardShortcut.from(jsonString: store.settings["toggleQueueHUDHotkey"], default: .defaultToggleQueueHUDShortcut)
        
        pasteQueueOrder = store.settings["pasteQueueOrder"] ?? "fifo"
        pasteQueueRemoveAfterPaste = (store.settings["pasteQueueBehavior"] ?? "removeAfterPaste") == "removeAfterPaste"
        pasteQueueAutoHide = (store.settings["pasteQueueAutoHide"] ?? "true") == "true"
        playSoundOnPaste = (store.settings["playSoundOnPaste"] ?? "true") == "true"
        pasteSoundName = store.settings["pasteSoundName"] ?? "Tink"
        
        isAccessibilityEnabled = PasteSimulator.isAccessibilityGranted()
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Settings] Failed to set login item: \(error)")
            }
        }
    }
    
    private func checkAccessibilityStatus() {
        let current = PasteSimulator.isAccessibilityGranted()
        if isAccessibilityEnabled != current {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isAccessibilityEnabled = current
            }
        }
    }
}
