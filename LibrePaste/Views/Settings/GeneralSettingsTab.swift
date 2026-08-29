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
    
    @State private var appLanguage: AppLanguage = .system
    @State private var appAppearance: AppAppearance = .system
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
            Section(L10n.tr("Interface & Appearance")) {
                Picker(L10n.tr("Language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text("\(lang.flag) \(lang.displayName)").tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: appLanguage) { _, val in
                    store.setAppLanguage(val)
                }
                
                Picker(L10n.tr("Appearance"), selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appAppearance) { _, val in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.setAppAppearance(val)
                    }
                }
                
                Picker(L10n.tr("Window Presentation"), selection: $windowPresentationMode) {
                    ForEach(WindowPresentationMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: windowPresentationMode) { _, val in
                    store.setWindowPresentationMode(val)
                }
                
                Picker(L10n.tr("Default Clip Layout"), selection: $clipLayoutStyle) {
                    ForEach(ClipLayoutStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.systemImage).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: clipLayoutStyle) { _, val in
                    store.setClipLayoutStyle(val)
                }
                
                Toggle(L10n.tr("Show App Icons in Compact List"), isOn: $compactShowAppIcons)
                    .onChange(of: compactShowAppIcons) { _, val in
                        store.compactShowAppIcons = val
                        store.saveSetting(key: "compactShowAppIcons", value: val ? "true" : "false")
                    }
                
                Toggle(L10n.tr("Show Number Shortcut Badges (1-9)"), isOn: $compactShowShortcuts)
                    .onChange(of: compactShowShortcuts) { _, val in
                        store.compactShowShortcuts = val
                        store.saveSetting(key: "compactShowShortcuts", value: val ? "true" : "false")
                    }
                
                Picker(L10n.tr("Preview Lines in Compact List"), selection: $compactPreviewLines) {
                    Text(L10n.tr("1 Line (Ultra Dense)")).tag(1)
                    Text(L10n.tr("2 Lines (Standard)")).tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: compactPreviewLines) { _, val in
                    store.compactPreviewLines = val
                    store.saveSetting(key: "compactPreviewLines", value: "\(val)")
                }
            }
            
            Section(L10n.tr("Startup & Shortcuts")) {
                Toggle(L10n.tr("Launch at Login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                Toggle(L10n.tr("Show Icon in Dock"), isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        store.saveSetting(key: "showInDock", value: newValue ? "true" : "false")
                        AppDelegate.shared?.updateDockVisibility(show: newValue)
                    }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Global Hotkey"))
                        Text(L10n.tr("Shortcut to open LibrePaste from anywhere"))
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
            
            Section(L10n.tr("Paste Behavior")) {
                Picker(L10n.tr("Paste Mode"), selection: $pasteTarget) {
                    Text(L10n.tr("Direct Paste into Active App")).tag("direct")
                    Text(L10n.tr("Copy to Clipboard Only")).tag("clipboard")
                }
                .pickerStyle(.menu)
                .onChange(of: pasteTarget) { _, val in
                    store.saveSetting(key: "pasteTarget", value: val)
                }
                
                Toggle(L10n.tr("Hide LibrePaste window after pasting"), isOn: $hideAfterPaste)
                    .onChange(of: hideAfterPaste) { _, val in
                        store.saveSetting(key: "hideAfterPaste", value: val ? "true" : "false")
                    }
                
                Toggle(L10n.tr("Play sound when pasting"), isOn: $playSoundOnPaste)
                    .onChange(of: playSoundOnPaste) { _, val in
                        store.saveSetting(key: "playSoundOnPaste", value: val ? "true" : "false")
                        PasteSimulator.shared.invalidateSoundCache()
                    }
                
                if playSoundOnPaste {
                    HStack {
                        Picker(L10n.tr("Paste Sound"), selection: $pasteSoundName) {
                            Text(L10n.tr("Tink (Subtle Tap)")).tag("Tink")
                            Text(L10n.tr("Pop (Soft Bubble)")).tag("Pop")
                            Text(L10n.tr("Bottle (Cork Pop)")).tag("Bottle")
                            Text(L10n.tr("Glass (Crisp Chime)")).tag("Glass")
                            Text(L10n.tr("Blow (Air Puff)")).tag("Blow")
                            Text(L10n.tr("Ping (Bell)")).tag("Ping")
                            Text(L10n.tr("Purr (Soft)")).tag("Purr")
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
                        .help(L10n.tr("Preview selected sound"))
                    }
                }
            }
            
            Section(L10n.tr("Paste Queue / Sequential Paste")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Paste Next Shortcut"))
                        Text(L10n.tr("Paste the next queued item into the active app"))
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
                        Text(L10n.tr("Toggle Queue HUD"))
                        Text(L10n.tr("Show or hide the floating mini queue overlay"))
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
                
                Picker(L10n.tr("Queue Order"), selection: $pasteQueueOrder) {
                    ForEach(PasteQueueOrder.allCases) { orderOption in
                        Text(orderOption.displayName).tag(orderOption.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: pasteQueueOrder) { _, val in
                    store.saveSetting(key: "pasteQueueOrder", value: val)
                    PasteQueueManager.shared.order = (val == "lifo") ? .lifo : .fifo
                }
                
                Toggle(L10n.tr("Remove item after paste"), isOn: $pasteQueueRemoveAfterPaste)
                    .onChange(of: pasteQueueRemoveAfterPaste) { _, val in
                        let behaviorStr = val ? "removeAfterPaste" : "cycle"
                        store.saveSetting(key: "pasteQueueBehavior", value: behaviorStr)
                        PasteQueueManager.shared.behavior = val ? .removeAfterPaste : .cycle
                    }
                
                Toggle(L10n.tr("Auto-hide HUD when queue is empty"), isOn: $pasteQueueAutoHide)
                    .onChange(of: pasteQueueAutoHide) { _, val in
                        store.saveSetting(key: "pasteQueueAutoHide", value: val ? "true" : "false")
                        PasteQueueManager.shared.autoHideWhenEmpty = val
                    }
            }
            
            Section(L10n.tr("Accessibility Permissions")) {
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
                        Text(L10n.tr("Accessibility Permission Granted"))
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text(L10n.tr("ACTIVE"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    Text(L10n.tr("LibrePaste has full access to simulate ⌘V and paste directly into active apps."))
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
                Text(L10n.tr("Accessibility Permission Needed"))
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Text(L10n.tr("LibrePaste requires Accessibility permission to automatically simulate ⌘V and paste directly into other applications."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button(L10n.tr("Grant Accessibility Access")) {
                PasteSimulator.requestAccessibilityPermissions()
                checkAccessibilityStatus()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)
            
            Text(L10n.tr("After enabling LibrePaste in System Settings, quit and relaunch the app."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func loadSettings() {
        appLanguage = store.appLanguage
        appAppearance = store.appAppearance
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
