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
    @State private var pasteTarget: String = "direct"
    @State private var hideAfterPaste: Bool = true
    @State private var isAccessibilityEnabled: Bool = PasteSimulator.isAccessibilityGranted()
    @State private var currentShortcut: KeyboardShortcut = .defaultShortcut
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
            Section("Startup & Display") {
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
        let savedTarget = store.settings["pasteTarget"] ?? "direct"
        pasteTarget = (savedTarget == "clipboard") ? "clipboard" : "direct"
        showInDock = (store.settings["showInDock"] ?? "true") == "true"
        hideAfterPaste = (store.settings["hideAfterPaste"] ?? "true") == "true"
        
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        
        currentShortcut = KeyboardShortcut.from(jsonString: store.settings["globalHotkey"])
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
