//
//  PasteQueueManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import SwiftUI
import Observation

@Observable
@MainActor
public final class PasteQueueManager {
    public static let shared = PasteQueueManager()
    
    public var items: [PasteQueueItem] = []
    public var order: PasteQueueOrder = .fifo
    public var behavior: PasteQueueBehavior = .removeAfterPaste
    public var isCollectModeActive: Bool = false
    public var isHUDVisible: Bool = false
    public var autoHideWhenEmpty: Bool = true
    
    private var floatingPanel: FloatingQueuePanel? = nil
    
    private init() {
        loadSettings()
        loadQueueFromSettings()
    }
    
    // MARK: - Setup
    
    public func setup() {
        if floatingPanel == nil {
            let panel = FloatingQueuePanel()
            let hostingView = NSHostingView(rootView: PasteQueueHUDView(manager: self))
            panel.contentView = hostingView
            self.floatingPanel = panel
        }
    }
    
    // MARK: - Queue Operations
    
    public func enqueue(clip: ClipRecord) {
        let newItem = PasteQueueItem(clip: clip)
        items.append(newItem)
        saveQueueToSettings()
        
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
        
        if isCollectModeActive && !isHUDVisible {
            showHUD()
        }
    }
    
    public func enqueue(clips: [ClipRecord]) {
        for clip in clips {
            let newItem = PasteQueueItem(clip: clip)
            items.append(newItem)
        }
        saveQueueToSettings()
        
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }
    
    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        saveQueueToSettings()
    }
    
    public func remove(clipId: Int64) {
        items.removeAll { $0.clip.id == clipId }
        saveQueueToSettings()
    }
    
    public func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveQueueToSettings()
    }
    
    public func clear() {
        items.removeAll()
        saveQueueToSettings()
    }
    
    public func move(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveQueueToSettings()
    }
    
    public func contains(clipId: Int64) -> Bool {
        items.contains { $0.clip.id == clipId }
    }
    
    public func peekNext() -> PasteQueueItem? {
        guard !items.isEmpty else { return nil }
        switch order {
        case .fifo:
            return items.first
        case .lifo:
            return items.last
        }
    }
    
    public func skip() {
        guard !items.isEmpty else { return }
        switch behavior {
        case .removeAfterPaste:
            switch order {
            case .fifo:
                items.removeFirst()
            case .lifo:
                items.removeLast()
            }
        case .cycle:
            if items.count > 1 {
                switch order {
                case .fifo:
                    let item = items.removeFirst()
                    items.append(item)
                case .lifo:
                    let item = items.removeLast()
                    items.insert(item, at: 0)
                }
            }
        }
        saveQueueToSettings()
        
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
        
        if items.isEmpty && autoHideWhenEmpty {
            hideHUD()
        }
    }
    
    public func pasteNext(targetAppBundleId: String? = nil, asPlainText: Bool = false, completion: (() -> Void)? = nil) {
        guard let nextItem = peekNext() else {
            NSSound.beep()
            completion?()
            return
        }
        
        let clip = nextItem.clip
        ClipboardWatcher.shared.markSelfWrite(hash: clip.hash)
        
        if asPlainText {
            PasteSimulator.shared.writeClipAsPlainText(clip)
        } else {
            PasteSimulator.shared.writeClipToClipboard(clip)
        }
        
        PasteSimulator.shared.playPasteSound()
        
        // Handle queue progression: remove or cycle/loop
        switch behavior {
        case .removeAfterPaste:
            switch order {
            case .fifo:
                if !items.isEmpty { items.removeFirst() }
            case .lifo:
                if !items.isEmpty { items.removeLast() }
            }
        case .cycle:
            if items.count > 1 {
                switch order {
                case .fifo:
                    let item = items.removeFirst()
                    items.append(item)
                case .lifo:
                    let item = items.removeLast()
                    items.insert(item, at: 0)
                }
            }
        }
        saveQueueToSettings()
        
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
        
        if items.isEmpty && autoHideWhenEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                if self.items.isEmpty {
                    self.hideHUD()
                }
            }
        }
        
        let targetApp = targetAppBundleId ?? AppDelegate.shared?.store.lastActiveAppBundleId
        PasteSimulator.shared.simulatePaste(targetAppBundleId: targetApp) {
            completion?()
        }
    }
    
    // MARK: - Collect Mode
    
    public func toggleCollectMode() {
        isCollectModeActive.toggle()
        if isCollectModeActive && !isHUDVisible {
            showHUD()
        }
    }
    
    // MARK: - HUD Controls
    
    public func showHUD() {
        setup()
        isHUDVisible = true
        floatingPanel?.showPanel()
    }
    
    public func hideHUD() {
        isHUDVisible = false
        floatingPanel?.hidePanel()
    }
    
    public func toggleHUD() {
        if isHUDVisible {
            hideHUD()
        } else {
            showHUD()
        }
    }
    
    // MARK: - Persistence & Settings
    
    public func saveQueueToSettings() {
        let clipIds = items.map { $0.clip.id }
        if let data = try? JSONEncoder().encode(clipIds),
           let jsonStr = String(data: data, encoding: .utf8) {
            DatabaseManager.shared.setSetting(key: "pasteQueueClipIds", value: jsonStr)
        }
        NotificationCenter.default.post(name: .pasteQueueChanged, object: nil)
    }
    
    private func loadQueueFromSettings() {
        guard let jsonStr = DatabaseManager.shared.getSetting("pasteQueueClipIds"),
              let data = jsonStr.data(using: .utf8),
              let clipIds = try? JSONDecoder().decode([Int64].self, from: data) else {
            return
        }
        
        var loadedItems: [PasteQueueItem] = []
        for id in clipIds {
            if let clip = DatabaseManager.shared.getClip(id: id) {
                loadedItems.append(PasteQueueItem(clip: clip))
            }
        }
        self.items = loadedItems
    }
    
    public func loadSettings() {
        if let savedOrder = DatabaseManager.shared.getSetting("pasteQueueOrder"),
           let orderEnum = PasteQueueOrder(rawValue: savedOrder) {
            self.order = orderEnum
        }
        if let savedBehavior = DatabaseManager.shared.getSetting("pasteQueueBehavior"),
           let behaviorEnum = PasteQueueBehavior(rawValue: savedBehavior) {
            self.behavior = behaviorEnum
        }
        if let savedAutoHide = DatabaseManager.shared.getSetting("pasteQueueAutoHide") {
            self.autoHideWhenEmpty = (savedAutoHide == "true")
        }
    }
    
    public func saveSetting(key: String, value: String) {
        DatabaseManager.shared.setSetting(key: key, value: value)
    }
}

extension Notification.Name {
    public static let pasteQueueChanged = Notification.Name("pasteQueueChanged")
}
