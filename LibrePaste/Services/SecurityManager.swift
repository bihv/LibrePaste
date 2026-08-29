//
//  SecurityManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import Observation
import LocalAuthentication
import AppKit

@Observable
public final class SecurityManager: @unchecked Sendable {
    public static let shared = SecurityManager()
    
    // MARK: - Types
    
    public enum AutoLockTimeout: String, CaseIterable, Identifiable {
        case immediately = "0"
        case oneMinute = "60"
        case fiveMinutes = "300"
        case fifteenMinutes = "900"
        case thirtyMinutes = "1800"
        case never = "-1"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .immediately: return L10n.tr("Immediately")
            case .oneMinute: return L10n.tr("1 minute")
            case .fiveMinutes: return L10n.tr("5 minutes")
            case .fifteenMinutes: return L10n.tr("15 minutes")
            case .thirtyMinutes: return L10n.tr("30 minutes")
            case .never: return L10n.tr("Never")
            }
        }
        
        public var seconds: TimeInterval? {
            switch self {
            case .immediately: return 0
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            case .fifteenMinutes: return 900
            case .thirtyMinutes: return 1800
            case .never: return nil
            }
        }
    }
    
    public enum BiometricCapability {
        case touchID
        case appleWatchOrPassword
        case none
        
        public var title: String {
            switch self {
            case .touchID:
                return L10n.tr("Touch ID / Password")
            case .appleWatchOrPassword:
                return L10n.tr("Passcode / Password")
            case .none:
                return L10n.tr("Universal")
            }
        }
        
        public var iconName: String {
            switch self {
            case .touchID:
                return "touchid"
            case .appleWatchOrPassword:
                return "lock.shield"
            case .none:
                return "lock.slash"
            }
        }
    }
    
    // MARK: - State Properties
    
    public var isLocked: Bool = false
    public var isAuthenticating: Bool = false
    public var authErrorMessage: String? = nil
    
    public var isEnabled: Bool = false
    public var timeout: AutoLockTimeout = .fiveMinutes
    public var lockOnSleep: Bool = true
    
    public var biometricCapability: BiometricCapability = .none
    
    private var lastUnlockedAt: Date? = nil
    private var isEvaluatingAuth: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        checkBiometricCapability()
        loadSettings()
        setupSystemObservers()
        
        // Initial lock state on launch if enabled
        if isEnabled {
            isLocked = true
        }
    }
    
    // MARK: - Capability Check
    
    public func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .touchID {
                biometricCapability = .touchID
                return
            }
        }
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            biometricCapability = .appleWatchOrPassword
        } else {
            biometricCapability = .none
        }
    }
    
    // MARK: - Settings Persistence
    
    public func loadSettings() {
        let settings = DatabaseManager.shared.getAllSettings()
        isEnabled = (settings["appLockEnabled"] ?? "false") == "true"
        
        let timeoutVal = settings["appLockTimeout"] ?? "300"
        timeout = AutoLockTimeout(rawValue: timeoutVal) ?? .fiveMinutes
        
        lockOnSleep = (settings["appLockOnSleep"] ?? "true") == "true"
    }
    
    public func updateSettings(enabled: Bool, timeout: AutoLockTimeout, lockOnSleep: Bool) {
        self.isEnabled = enabled
        self.timeout = timeout
        self.lockOnSleep = lockOnSleep
        
        DatabaseManager.shared.setSetting(key: "appLockEnabled", value: enabled ? "true" : "false")
        DatabaseManager.shared.setSetting(key: "appLockTimeout", value: timeout.rawValue)
        DatabaseManager.shared.setSetting(key: "appLockOnSleep", value: lockOnSleep ? "true" : "false")
        
        if !enabled {
            isLocked = false
            authErrorMessage = nil
        } else if lastUnlockedAt == nil {
            isLocked = true
        }
    }
    
    // MARK: - Lock & Unlock Actions
    
    public func lockNow() {
        guard isEnabled else { return }
        DispatchQueue.main.async {
            self.isLocked = true
            self.lastUnlockedAt = nil
            self.authErrorMessage = nil
            NotificationCenter.default.post(name: .appDidLock, object: nil)
        }
    }
    
    public func unlockDirectlyForTesting() {
        DispatchQueue.main.async {
            self.isLocked = false
            self.lastUnlockedAt = Date()
            self.authErrorMessage = nil
        }
    }
    
    /// Check whether the app should lock due to timeout before revealing UI
    public func checkLockOnReveal() {
        guard isEnabled else {
            isLocked = false
            return
        }
        
        if isLocked {
            return
        }
        
        guard let lastUnlocked = lastUnlockedAt else {
            isLocked = true
            return
        }
        
        guard let timeoutSeconds = timeout.seconds else {
            // Never lock automatically
            return
        }
        
        if timeoutSeconds == 0 {
            // Immediate lock
            isLocked = true
            return
        }
        
        let elapsed = Date().timeIntervalSince(lastUnlocked)
        if elapsed >= timeoutSeconds {
            isLocked = true
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    public func authenticate(reason: String? = nil) async -> Bool {
        guard !isEvaluatingAuth else {
            return false
        }
        
        let localizedReason = reason ?? L10n.tr("Unlock LibrePaste clipboard history")
        
        isEvaluatingAuth = true
        isAuthenticating = true
        authErrorMessage = nil
        
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let context = LAContext()
                context.localizedReason = localizedReason
                
                var authError: NSError?
                guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                    continuation.resume(returning: Result<Bool, Error>.failure(authError ?? LAError(.authenticationFailed)))
                    return
                }
                
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: localizedReason) { success, error in
                    if success {
                        continuation.resume(returning: .success(true))
                    } else if let error = error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .failure(LAError(.authenticationFailed)))
                    }
                }
            }
        }
        
        isEvaluatingAuth = false
        isAuthenticating = false
        
        // Ensure floating panel regains key window status after system dialog closes
        DispatchQueue.main.async {
            if let panel = NSApp.windows.first(where: { $0 is FloatingPanel && $0.isVisible && $0.alphaValue > 0 }) as? FloatingPanel {
                panel.makeKeyAndOrderFront(nil)
                panel.makeFirstResponder(panel.contentView)
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            }
        }
        
        switch result {
        case .success(let success) where success:
            isLocked = false
            lastUnlockedAt = Date()
            authErrorMessage = nil
            return true
            
        case .failure(let error as LAError):
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                // User intentionally cancelled the prompt
                authErrorMessage = nil
            case .userFallback:
                authErrorMessage = L10n.tr("Fallback selected.")
            case .biometryLockout:
                authErrorMessage = L10n.tr("Touch ID locked out. Please use Mac password.")
            case .passcodeNotSet:
                authErrorMessage = L10n.tr("Device passcode / password is not set.")
            default:
                authErrorMessage = L10n.tr("Authentication failed. Click to try again.")
            }
            return false
            
        case .failure, .success:
            authErrorMessage = L10n.tr("Authentication failed. Click to try again.")
            return false
        }
    }
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        // Sleep notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isEnabled, self.lockOnSleep else { return }
            self.lockNow()
        }
        
        // Screen Sleep notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isEnabled, self.lockOnSleep else { return }
            self.lockNow()
        }
        
        // Screen Lock notification (macOS Distributed Notification)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isEnabled, self.lockOnSleep else { return }
            self.lockNow()
        }
    }
}

extension Notification.Name {
    public static let appDidLock = Notification.Name("appDidLock")
}

