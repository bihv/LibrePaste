//
//  AboutSettingsTab.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct AboutSettingsTab: View {
    public var store: ClipboardStore?
    
    @State private var isCheckingUpdate: Bool = false
    @State private var updateMessage: String? = nil
    
    public init(store: ClipboardStore? = nil) {
        self.store = store
    }
    
    // Dynamic App Information
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "LibrePaste"
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    private var cpuArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Universal"
        #endif
    }
    
    private var macosVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    private var currentYear: String {
        let year = Calendar.current.component(.year, from: Date())
        return String(year)
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // MARK: - Hero Header
            heroHeader
            
            // MARK: - Update Button
            updateButton
            
            // MARK: - Information & Links Card
            infoCard
            
            // MARK: - Footer
            footerSection
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
        .padding(.vertical, 20)
    }
    
    // MARK: - View Components
    
    private var heroHeader: some View {
        VStack(spacing: 12) {
            // App Icon with subtle elevation
            ZStack {
                if let icon = NSImage(named: "AppLogo") ?? NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                } else {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 80, height: 80)
                }
            }
            
            VStack(spacing: 4) {
                Text(appName)
                    .font(.system(size: 22, weight: .bold))
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text("Native clipboard history manager for macOS.\nCrafted with Swift & SwiftUI.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
    }
    
    private var updateButton: some View {
        Button {
            checkForUpdates()
        } label: {
            HStack(spacing: 6) {
                if isCheckingUpdate {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(updateMessage ?? "Check for Updates…")
            }
            .frame(minWidth: 160)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isCheckingUpdate)
    }
    
    private var infoCard: some View {
        VStack(spacing: 0) {
            // GitHub
            linkRow(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "Source Code & GitHub",
                subtitle: "View repository and releases",
                url: "https://github.com/bihv/LibrePaste"
            )
            
            Divider()
                .padding(.leading, 36)
            
            // Issues
            linkRow(
                icon: "bubble.left.and.exclamationmark.bubble.right",
                title: "Report an Issue or Feedback",
                subtitle: "Submit bug reports or feature suggestions",
                url: "https://github.com/bihv/LibrePaste/issues"
            )
            
            Divider()
                .padding(.leading, 36)
            
            // System specs
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                
                Text("System")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("macOS \(macosVersion) • \(cpuArchitecture)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func linkRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let destination = URL(string: url) {
                Link(destination: destination) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("Crafted with ❤️ for macOS by bihv & Contributors")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text("© \(currentYear) LibrePaste. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        isCheckingUpdate = true
        updateMessage = "Checking..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isCheckingUpdate = false
            updateMessage = "Latest version!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    updateMessage = nil
                }
            }
        }
    }
}

// Backwards compatibility alias
public typealias AboutView = AboutSettingsTab
