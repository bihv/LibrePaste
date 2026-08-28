//
//  PrivacySettingsTab.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct PrivacySettingsTab: View {
    @Bindable public var store: ClipboardStore
    
    @State private var ignorePasswords: Bool = true
    @State private var ignoreTransient: Bool = true
    @State private var ignoredApps: [[String: String]] = []
    
    @State private var appLockEnabled: Bool = false
    @State private var appLockTimeout: SecurityManager.AutoLockTimeout = .fiveMinutes
    @State private var appLockOnSleep: Bool = true
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
            Section("App Lock & Security") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Require Authentication")
                                .font(.system(size: 13, weight: .medium))
                            Text("Protect clipboard history using Touch ID or your Mac password.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appLockEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: appLockEnabled) { oldValue, newValue in
                                handleToggleAppLock(oldValue: oldValue, newValue: newValue)
                            }
                    }
                    
                    if appLockEnabled {
                        Divider()
                            .opacity(0.4)
                        
                        HStack {
                            Text("Auto-Lock Inactivity")
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $appLockTimeout) {
                                ForEach(SecurityManager.AutoLockTimeout.allCases) { item in
                                    Text(item.displayName).tag(item)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                            .onChange(of: appLockTimeout) { _, _ in
                                updateLockSettings()
                            }
                        }
                        
                        Toggle("Lock on System Sleep / Screen Lock", isOn: $appLockOnSleep)
                            .font(.system(size: 13))
                            .onChange(of: appLockOnSleep) { _, _ in
                                updateLockSettings()
                            }
                        
                        HStack(spacing: 6) {
                            Image(systemName: SecurityManager.shared.biometricCapability.iconName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("Hardware: \(SecurityManager.shared.biometricCapability.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Security Filters") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Ignore Password Managers", isOn: $ignorePasswords)
                        .onChange(of: ignorePasswords) { _, val in
                            store.saveSetting(key: "ignorePasswords", value: val ? "true" : "false")
                        }
                    Text("Automatically ignores clips copied from 1Password, Bitwarden, Keychain Access, KeePass, LastPass, etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Ignore Transient / Concealed Data", isOn: $ignoreTransient)
                        .onChange(of: ignoreTransient) { _, val in
                            store.saveSetting(key: "ignoreTransient", value: val ? "true" : "false")
                        }
                    Text("Ignores clipboard data marked with macOS transient or concealed privacy flags.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Ignored Applications") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LibrePaste will ignore clipboard copies when any of these apps is active:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if ignoredApps.isEmpty {
                        Text("No applications currently ignored.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(ignoredApps.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 8) {
                                if let path = item["path"], !path.isEmpty {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "app")
                                        .frame(width: 20, height: 20)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item["name"] ?? "App")
                                        .font(.system(size: 13, weight: .medium))
                                    if let path = item["path"] {
                                        Text(path)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { removeIgnoredApp(at: idx) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove ignored application")
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Button("Add Application...") {
                        selectAppToIgnore()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helpers
    
    private func loadSettings() {
        SecurityManager.shared.checkBiometricCapability()
        appLockEnabled = SecurityManager.shared.isEnabled
        appLockTimeout = SecurityManager.shared.timeout
        appLockOnSleep = SecurityManager.shared.lockOnSleep
        
        ignorePasswords = (store.settings["ignorePasswords"] ?? "true") == "true"
        ignoreTransient = (store.settings["ignoreTransient"] ?? "true") == "true"
        
        if let jsonString = store.settings["ignoredApps"],
           let data = jsonString.data(using: .utf8),
           let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            ignoredApps = list
        }
    }
    
    private func handleToggleAppLock(oldValue: Bool, newValue: Bool) {
        guard oldValue != newValue else { return }
        
        if !newValue && SecurityManager.shared.isEnabled {
            // Turning OFF App Lock requires biometric/password authentication confirmation
            Task { @MainActor in
                let success = await SecurityManager.shared.authenticate(reason: "Authenticate to turn off App Lock")
                if success {
                    updateLockSettings()
                } else {
                    // Authentication failed or was cancelled -> keep App Lock enabled
                    appLockEnabled = true
                }
            }
        } else {
            updateLockSettings()
        }
    }
    
    private func updateLockSettings() {
        store.updateLockSettings(
            enabled: appLockEnabled,
            timeout: appLockTimeout,
            lockOnSleep: appLockOnSleep
        )
    }
    
    private func selectAppToIgnore() {
        let panel = NSOpenPanel()
        panel.title = "Select Application to Ignore"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let newItem = ["name": name, "path": url.path]
            ignoredApps.append(newItem)
            saveIgnoredApps()
        }
    }
    
    private func removeIgnoredApp(at index: Int) {
        ignoredApps.remove(at: index)
        saveIgnoredApps()
    }
    
    private func saveIgnoredApps() {
        if let data = try? JSONSerialization.data(withJSONObject: ignoredApps),
           let jsonString = String(data: data, encoding: .utf8) {
            store.saveSetting(key: "ignoredApps", value: jsonString)
        }
    }
}
