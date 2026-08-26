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
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
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
        ignorePasswords = (store.settings["ignorePasswords"] ?? "true") == "true"
        ignoreTransient = (store.settings["ignoreTransient"] ?? "true") == "true"
        
        if let jsonString = store.settings["ignoredApps"],
           let data = jsonString.data(using: .utf8),
           let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            ignoredApps = list
        }
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
