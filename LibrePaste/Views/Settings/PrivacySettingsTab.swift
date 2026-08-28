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
    
    // Sensitive Data Protection States
    @State private var enableSensitiveMasking: Bool = true
    @State private var maskApiKeys: Bool = true
    @State private var maskCreditCards: Bool = true
    @State private var maskDatabaseUrls: Bool = true
    @State private var maskPII: Bool = true
    @State private var requireAuthToReveal: Bool = false
    @State private var autoPurgeHours: String = "0"
    
    @State private var showingAddRuleSheet: Bool = false
    @State private var editingRule: CustomSensitiveRule? = nil
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
            // 1. App Lock & Security
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
            
            // 2. Sensitive Data Masking & Protection (Unified)
            Section("Sensitive Data Masking & Protection") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Auto-Detect & Mask Sensitive Data")
                                .font(.system(size: 13, weight: .medium))
                            Text("Automatically shields API keys, credit cards, database URLs, credentials and custom tokens.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $enableSensitiveMasking)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: enableSensitiveMasking) { _, val in
                                store.saveSetting(key: "enableSensitiveMasking", value: val ? "true" : "false")
                                store.reloadClips()
                            }
                    }
                    
                    if enableSensitiveMasking {
                        Divider()
                            .opacity(0.4)
                        
                        // Sub-section A: Built-in Categories
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Protected Categories:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Toggle("API Keys, Secret Tokens & Private Keys", isOn: $maskApiKeys)
                                .font(.system(size: 12.5))
                                .onChange(of: maskApiKeys) { _, val in
                                    store.saveSetting(key: "maskApiKeys", value: val ? "true" : "false")
                                    store.reloadClips()
                                }
                            
                            Toggle("Payment & Credit Cards (with Luhn validation)", isOn: $maskCreditCards)
                                .font(.system(size: 12.5))
                                .onChange(of: maskCreditCards) { _, val in
                                    store.saveSetting(key: "maskCreditCards", value: val ? "true" : "false")
                                    store.reloadClips()
                                }
                            
                            Toggle("Database Connection Strings & Passwords", isOn: $maskDatabaseUrls)
                                .font(.system(size: 12.5))
                                .onChange(of: maskDatabaseUrls) { _, val in
                                    store.saveSetting(key: "maskDatabaseUrls", value: val ? "true" : "false")
                                    store.reloadClips()
                                }
                            
                            Toggle("Personal Identifiable Information (CCCD, SSN)", isOn: $maskPII)
                                .font(.system(size: 12.5))
                                .onChange(of: maskPII) { _, val in
                                    store.saveSetting(key: "maskPII", value: val ? "true" : "false")
                                    store.reloadClips()
                                }
                        }
                        .padding(.leading, 4)
                        
                        Divider()
                            .opacity(0.4)
                        
                        // Sub-section B: Custom Sensitive Rules
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Custom Sensitive Rules:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("+ Add Rule...") {
                                    showingAddRuleSheet = true
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            if store.customSensitiveRules.isEmpty {
                                Text("No custom regular expressions defined yet.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 2)
                                    .padding(.leading, 4)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(store.customSensitiveRules) { rule in
                                        HStack(spacing: 8) {
                                            Toggle("", isOn: Binding(
                                                get: { rule.isEnabled },
                                                set: { store.toggleCustomSensitiveRule(id: rule.id, isEnabled: $0) }
                                            ))
                                            .labelsHidden()
                                            .toggleStyle(.checkbox)
                                            
                                            Image(systemName: "wrench.and.screwdriver.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(rule.isEnabled ? Color.accentColor : Color.secondary)
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                HStack(spacing: 6) {
                                                    Text(rule.name)
                                                        .font(.system(size: 12.5, weight: .medium))
                                                    
                                                    Text(rule.maskStrategy.displayName)
                                                        .font(.system(size: 9.5))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.primary.opacity(0.06))
                                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Text(rule.pattern)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: { editingRule = rule }) {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 11.5))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Edit rule")
                                            
                                            Button(action: { store.deleteCustomSensitiveRule(id: rule.id) }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 11.5))
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Delete rule")
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.03))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.leading, 4)
                            }
                        }
                        
                        Divider()
                            .opacity(0.4)
                        
                        // Sub-section C: Security & Access Behavior
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Require Touch ID / Password to Reveal Secrets", isOn: $requireAuthToReveal)
                                .font(.system(size: 13))
                                .onChange(of: requireAuthToReveal) { _, val in
                                    store.saveSetting(key: "requireAuthToReveal", value: val ? "true" : "false")
                                }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-Purge Sensitive Clips")
                                        .font(.system(size: 13))
                                    Text("Permanently removes unpinned sensitive clips from history after time.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Picker("", selection: $autoPurgeHours) {
                                    Text("Never").tag("0")
                                    Text("After 1 Hour").tag("1")
                                    Text("After 24 Hours").tag("24")
                                    Text("After 7 Days").tag("168")
                                }
                                .labelsHidden()
                                .frame(width: 150)
                                .onChange(of: autoPurgeHours) { _, val in
                                    store.saveSetting(key: "autoPurgeSensitiveHours", value: val)
                                    if let hours = Int(val), hours > 0 {
                                        DatabaseManager.shared.purgeSensitiveClips(olderThanHours: hours)
                                        store.reloadClips()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // 4. Security Filters
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
            
            // 5. Ignored Applications
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
        .sheet(isPresented: $showingAddRuleSheet) {
            CustomRuleEditorSheet { newRule in
                store.saveCustomSensitiveRule(newRule)
            }
        }
        .sheet(item: $editingRule) { rule in
            CustomRuleEditorSheet(ruleToEdit: rule) { updatedRule in
                store.saveCustomSensitiveRule(updatedRule)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadSettings() {
        SecurityManager.shared.checkBiometricCapability()
        appLockEnabled = SecurityManager.shared.isEnabled
        appLockTimeout = SecurityManager.shared.timeout
        appLockOnSleep = SecurityManager.shared.lockOnSleep
        
        enableSensitiveMasking = (store.settings["enableSensitiveMasking"] ?? "true") == "true"
        maskApiKeys = (store.settings["maskApiKeys"] ?? "true") == "true"
        maskCreditCards = (store.settings["maskCreditCards"] ?? "true") == "true"
        maskDatabaseUrls = (store.settings["maskDatabaseUrls"] ?? "true") == "true"
        maskPII = (store.settings["maskPII"] ?? "true") == "true"
        requireAuthToReveal = (store.settings["requireAuthToReveal"] ?? "false") == "true"
        autoPurgeHours = store.settings["autoPurgeSensitiveHours"] ?? "0"
        
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
