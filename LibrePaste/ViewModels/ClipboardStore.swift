//
//  ClipboardStore.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import Observation

@Observable
public final class ClipboardStore {
    public var clips: [ClipRecord] = []
    public var pinboards: [Pinboard] = []
    public var pinboardCounts: [Int64: Int] = [:]
    public var selectedPinboardId: Int64? = nil
    public var isQueueSelected: Bool = false
    
    public var queueManager: PasteQueueManager {
        PasteQueueManager.shared
    }
    
    private var searchDebounceTask: Task<Void, Never>? = nil
    
    public var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                searchDebounceTask?.cancel()
                reloadClips()
            } else {
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 120_000_000) // 120ms debounce
                    if !Task.isCancelled {
                        self.reloadClips()
                    }
                }
            }
        }
    }
    
    public var filter: FilterType = .all
    public var activeIndex: Int = 0
    public var isPaused: Bool = false
    public var isSearchFocused: Bool = false
    public var storageStats: StorageStats? = nil
    public var settings: [String: String] = [:]
    
    public var lastActiveAppBundleId: String? = nil
    
    public init() {
        self.isPaused = ClipboardWatcher.shared.paused
        reloadSettings()
        reloadPinboards()
        reloadClips()
        
        ClipboardWatcher.shared.onClipAdded = { [weak self] _, _ in
            self?.reloadClips()
            self?.reloadPinboards()
        }
        
        ClipboardWatcher.shared.onPausedChanged = { [weak self] paused in
            self?.isPaused = paused
        }
        
        NotificationCenter.default.addObserver(forName: .pasteQueueChanged, object: nil, queue: .main) { [weak self] _ in
            if self?.isQueueSelected == true {
                self?.reloadClips()
            }
        }
    }
    
    public var filteredClips: [ClipRecord] {
        var result = clips
        
        switch filter {
        case .all:
            break
        case .text:
            result = result.filter { $0.type == .text || $0.type == .richtext }
        case .link:
            result = result.filter { $0.type == .link }
        case .image:
            result = result.filter { $0.type == .image }
        }
        
        return result
    }
    
    public func reloadClips() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            clips = DatabaseManager.shared.searchClips(query: trimmed)
        } else if isQueueSelected {
            clips = PasteQueueManager.shared.items.map(\.clip)
        } else if let pinboardId = selectedPinboardId {
            clips = DatabaseManager.shared.getClipsByPinboard(pinboardId: pinboardId)
        } else {
            clips = DatabaseManager.shared.listClips()
        }
        
        if activeIndex >= filteredClips.count {
            activeIndex = max(0, filteredClips.count - 1)
        }
        
        let imagePaths = clips.compactMap { $0.type == .image ? $0.imagePath : nil }
        ThumbnailManager.shared.prefetchThumbnails(for: imagePaths)
    }
    
    public func reloadPinboards() {
        pinboards = DatabaseManager.shared.listPinboards()
        pinboardCounts = DatabaseManager.shared.getPinboardCounts()
    }
    
    public func reloadSettings() {
        settings = DatabaseManager.shared.getAllSettings()
        if settings["pasteTarget"] == "active" {
            saveSetting(key: "pasteTarget", value: "direct")
        }
        
        let autoPurgeHours = Int(settings["autoPurgeSensitiveHours"] ?? "0") ?? 0
        if autoPurgeHours > 0 {
            DatabaseManager.shared.purgeSensitiveClips(olderThanHours: autoPurgeHours)
        }
        
        reloadCustomSensitiveRules()
    }
    
    public func reloadStats() {
        storageStats = DatabaseManager.shared.getStorageStats()
    }
    
    // MARK: - Actions
    
    public func paste(clip: ClipRecord, asPlainText: Bool = false) {
        ClipboardWatcher.shared.markSelfWrite(hash: clip.hash)
        
        if asPlainText {
            PasteSimulator.shared.writeClipAsPlainText(clip)
        } else {
            PasteSimulator.shared.writeClipToClipboard(clip)
        }
        
        let hideAfterPaste = settings["hideAfterPaste"] ?? "true"
        if hideAfterPaste == "true" {
            NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
        }
        
        PasteSimulator.shared.playPasteSound()
        
        let pasteTarget = settings["pasteTarget"] ?? "direct"
        if pasteTarget != "clipboard" {
            PasteSimulator.shared.simulatePaste(targetAppBundleId: lastActiveAppBundleId)
        }
    }
    
    public func togglePin(_ clip: ClipRecord) {
        DatabaseManager.shared.setPinned(id: clip.id, pinned: !clip.pinned)
        reloadClips()
    }
    
    public func deleteClip(_ clipId: Int64) {
        revealedClipIds.remove(clipId)
        DatabaseManager.shared.deleteClip(id: clipId)
        PasteQueueManager.shared.remove(clipId: clipId)
        reloadClips()
        reloadPinboards()
    }
    
    public func updateClip(id: Int64, content: String, preview: String, rtf: String? = nil) {
        _ = DatabaseManager.shared.updateClip(id: id, content: content, preview: preview, rtf: rtf)
        reloadClips()
    }
    
    public func clearAll() {
        revealedClipIds.removeAll()
        DatabaseManager.shared.clearAll()
        PasteQueueManager.shared.clear()
        reloadClips()
        reloadPinboards()
    }
    
    public func createPinboard(name: String, color: String) {
        _ = DatabaseManager.shared.createPinboard(name: name, color: color)
        reloadPinboards()
    }
    
    public func updatePinboard(id: Int64, name: String, color: String) {
        _ = DatabaseManager.shared.updatePinboard(id: id, name: name, color: color)
        reloadPinboards()
    }
    
    public func deletePinboard(id: Int64) {
        if selectedPinboardId == id {
            selectedPinboardId = nil
        }
        DatabaseManager.shared.deletePinboard(id: id)
        reloadPinboards()
        reloadClips()
    }
    
    public func reorderPinboards(orderedIds: [Int64]) {
        DatabaseManager.shared.reorderPinboards(orderedIds: orderedIds)
        reloadPinboards()
    }
    
    public func addClipToPinboard(clipId: Int64, pinboardId: Int64?) {
        DatabaseManager.shared.addClipToPinboard(clipId: clipId, pinboardId: pinboardId)
        reloadClips()
        reloadPinboards()
    }
    
    public func togglePause() {
        isPaused = ClipboardWatcher.shared.togglePause()
    }
    
    public func saveSetting(key: String, value: String) {
        DatabaseManager.shared.setSetting(key: key, value: value)
        settings[key] = value
    }
    
    // MARK: - App Lock & Security
    
    public var isLocked: Bool {
        SecurityManager.shared.isLocked
    }
    
    public var isAppLockEnabled: Bool {
        SecurityManager.shared.isEnabled
    }
    
    public func unlockApp() {
        Task { @MainActor in
            _ = await SecurityManager.shared.authenticate()
        }
    }
    
    public func lockAppNow() {
        SecurityManager.shared.lockNow()
    }
    
    public func updateLockSettings(enabled: Bool, timeout: SecurityManager.AutoLockTimeout, lockOnSleep: Bool) {
        SecurityManager.shared.updateSettings(enabled: enabled, timeout: timeout, lockOnSleep: lockOnSleep)
        reloadSettings()
    }
    
    // MARK: - Sensitive Data Masking & Reveal State
    
    public var revealedClipIds: Set<Int64> = []
    public var customSensitiveRules: [CustomSensitiveRule] = []
    
    public func isRevealed(clipId: Int64) -> Bool {
        revealedClipIds.contains(clipId)
    }
    
    public func toggleReveal(clip: ClipRecord) {
        if revealedClipIds.contains(clip.id) {
            revealedClipIds.remove(clip.id)
            return
        }
        
        let requireAuth = (settings["requireAuthToReveal"] ?? "false") == "true"
        if requireAuth {
            Task { @MainActor in
                let success = await SecurityManager.shared.authenticate(reason: "Authenticate to view sensitive data")
                if success {
                    self.revealedClipIds.insert(clip.id)
                }
            }
        } else {
            revealedClipIds.insert(clip.id)
        }
    }
    
    public func reloadCustomSensitiveRules() {
        customSensitiveRules = SensitiveDataService.shared.getCustomRules()
    }
    
    public func saveCustomSensitiveRule(_ rule: CustomSensitiveRule) {
        SensitiveDataService.shared.saveCustomRule(rule)
        reloadCustomSensitiveRules()
        reloadClips()
    }
    
    public func deleteCustomSensitiveRule(id: UUID) {
        SensitiveDataService.shared.deleteCustomRule(id: id)
        reloadCustomSensitiveRules()
        reloadClips()
    }
    
    public func toggleCustomSensitiveRule(id: UUID, isEnabled: Bool) {
        SensitiveDataService.shared.toggleCustomRule(id: id, isEnabled: isEnabled)
        reloadCustomSensitiveRules()
        reloadClips()
    }
}

extension Notification.Name {
    public static let hideFloatingPanel = Notification.Name("hideFloatingPanel")
    public static let showFloatingPanel = Notification.Name("showFloatingPanel")
    public static let toggleFloatingPanel = Notification.Name("toggleFloatingPanel")
    public static let panelDidShow = Notification.Name("panelDidShow")
    public static let panelDidHide = Notification.Name("panelDidHide")
}
