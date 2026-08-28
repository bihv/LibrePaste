//
//  LockOverlayView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import LocalAuthentication

public struct LockOverlayView: View {
    @Bindable public var store: ClipboardStore
    public var onUnlockRequested: () -> Void
    
    @State private var isHoveringUnlock: Bool = false
    @State private var pulseAnimation: Bool = false
    
    public init(store: ClipboardStore, onUnlockRequested: @escaping () -> Void) {
        self.store = store
        self.onUnlockRequested = onUnlockRequested
    }
    
    public var body: some View {
        ZStack {
            // Frosted blur backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Background subtle tint
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            
            // Centered Lock Box
            VStack(spacing: 20) {
                // Biometric / Lock Glyph with pulsing circle
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(pulseAnimation ? 0.14 : 0.06))
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseAnimation ? 1.08 : 0.96)
                    
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: SecurityManager.shared.biometricCapability.iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
                
                // Titles
                VStack(spacing: 6) {
                    Text("LibrePaste is Locked")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(biometricSubtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                
                // Error message if any
                if let errorMsg = SecurityManager.shared.authErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(errorMsg)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: onUnlockRequested) {
                        HStack(spacing: 8) {
                            if SecurityManager.shared.isAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: SecurityManager.shared.biometricCapability.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            
                            Text(SecurityManager.shared.isAuthenticating ? "Authenticating..." : unlockButtonTitle)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: Color.accentColor.opacity(isHoveringUnlock ? 0.35 : 0.2), radius: isHoveringUnlock ? 8 : 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(SecurityManager.shared.isAuthenticating)
                    .onHover { isHoveringUnlock = $0 }
                    
                    // Dismiss Hint
                    HStack(spacing: 12) {
                        shortcutHint("↵ / Space", "Unlock")
                        shortcutHint("Esc", "Dismiss")
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                    .shadow(color: Color.black.opacity(0.2), radius: 24, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var biometricSubtitle: String {
        switch SecurityManager.shared.biometricCapability {
        case .touchID:
            return "Use Touch ID or your Mac password to unlock clipboard history."
        case .appleWatchOrPassword:
            return "Enter your Mac password or use Apple Watch to unlock clipboard history."
        case .none:
            return "Authenticate to access your clipboard history."
        }
    }
    
    private var unlockButtonTitle: String {
        switch SecurityManager.shared.biometricCapability {
        case .touchID:
            return "Unlock with Touch ID"
        case .appleWatchOrPassword:
            return "Unlock with Password"
        case .none:
            return "Unlock"
        }
    }
    
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 3.5))
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}
