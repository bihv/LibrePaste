//
//  ClipboardView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct ClipboardView: View {
    @Bindable public var store: ClipboardStore
    
    @State private var isSidebarCollapsed: Bool = true
    @State private var scrollTarget: ScrollTarget? = nil
    @State private var keyEventMonitor: Any? = nil
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header Bar
                headerBar
                
                Divider()
                    .opacity(0.3)
                
                // Body Content (Sidebar + Horizontal Cards)
                HStack(spacing: 0) {
                    SidebarView(
                        pinboards: store.pinboards,
                        counts: store.pinboardCounts,
                        selectedId: store.selectedPinboardId,
                        isQueueSelected: store.isQueueSelected,
                        queueCount: PasteQueueManager.shared.items.count,
                        isCollapsed: $isSidebarCollapsed,
                        onSelect: { pId in
                            store.isQueueSelected = false
                            store.selectedPinboardId = pId
                            store.reloadClips()
                            scrollTarget = ScrollTarget(index: 0)
                        },
                        onSelectQueue: {
                            store.selectedPinboardId = nil
                            store.isQueueSelected = true
                            store.reloadClips()
                            scrollTarget = ScrollTarget(index: 0)
                        },
                        onCreate: { name, color in
                            store.createPinboard(name: name, color: color)
                        },
                        onUpdate: { id, name, color in
                            store.updatePinboard(id: id, name: name, color: color)
                        },
                        onDelete: { id in
                            store.deletePinboard(id: id)
                        },
                        onReorder: { orderedIds in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                store.reorderPinboards(orderedIds: orderedIds)
                            }
                        },
                        onAssignClip: { clipId, pinboardId in
                            store.addClipToPinboard(clipId: clipId, pinboardId: pinboardId)
                        },
                        onEnqueueClip: { clipId in
                            if let clip = DatabaseManager.shared.getClip(id: clipId) {
                                PasteQueueManager.shared.enqueue(clip: clip)
                            }
                        }
                    )
                    
                    Divider()
                        .opacity(0.3)
                    
                    VStack(spacing: 0) {
                        if store.isQueueSelected {
                            queueControlBar
                            Divider()
                                .opacity(0.3)
                        }
                        
                        ClipListView(
                            clips: store.filteredClips,
                            pinboards: store.pinboards,
                            activeIndex: store.activeIndex,
                            scrollTarget: scrollTarget,
                            onSelect: { idx in
                                store.activeIndex = idx
                                store.isSearchFocused = false
                                if let window = NSApp.keyWindow as? FloatingPanel {
                                    window.makeFirstResponder(window.contentView)
                                }
                            },
                            onPaste: { clip in
                                store.paste(clip: clip)
                            },
                            onPastePlain: { clip in
                                store.paste(clip: clip, asPlainText: true)
                            },
                            onTogglePin: { clip in
                                store.togglePin(clip)
                            },
                            onDelete: { id in
                                store.deleteClip(id)
                            },
                            onEdit: { clip in
                                NotificationCenter.default.post(name: .openEditWindow, object: clip)
                            },
                            onPreview: { clip in
                                NotificationCenter.default.post(name: .openPreviewWindow, object: clip)
                            },
                            onAddToPinboard: { clipId, pinboardId in
                                store.addClipToPinboard(clipId: clipId, pinboardId: pinboardId)
                            },
                            onEnqueue: { clip in
                                PasteQueueManager.shared.enqueue(clip: clip)
                            },
                            onRemoveFromQueue: { clip in
                                PasteQueueManager.shared.remove(clipId: clip.id)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .opacity(0.3)
                
                // Footer Shortcuts
                footerBar
            }
            
            // App Lock Overlay
            if store.isLocked {
                LockOverlayView(store: store) {
                    store.unlockApp()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(999)
            }
        }
        .frame(height: FloatingPanel.panelHeight)
        .background(.ultraThinMaterial)
        .onAppear {
            if keyEventMonitor == nil {
                keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleGlobalKeyEvent(event)
                }
            }
        }
        .onDisappear {
            if let monitor = keyEventMonitor {
                NSEvent.removeMonitor(monitor)
                keyEventMonitor = nil
            }
        }
        .onChange(of: store.filter) {
            scrollTarget = ScrollTarget(index: 0)
        }
        .onChange(of: store.query) {
            scrollTarget = ScrollTarget(index: 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { _ in
            store.isSearchFocused = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFloatingPanel)) { _ in
            store.isSearchFocused = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFloatingPanel)) { _ in
            store.isSearchFocused = false
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func handleGlobalKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard let window = event.window as? FloatingPanel ?? NSApp.keyWindow as? FloatingPanel,
              window.isVisible,
              window.alphaValue > 0,
              window.attachedSheet == nil else {
            return event
        }
        
        // When app is locked, intercept all interactions
        if store.isLocked {
            if event.keyCode == 53 { // Esc
                NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
                return nil
            }
            if event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 49 { // Return, Enter, Space
                store.unlockApp()
                return nil
            }
            return nil // Block all other keys
        }
        
        let isFieldEditor = window.firstResponder is NSTextView
        let isSearching = isFieldEditor || store.isSearchFocused
        let isCommand = event.modifierFlags.contains(.command)
        let isOption = event.modifierFlags.contains(.option)
        let chars = event.charactersIgnoringModifiers ?? ""
        
        // 1. Escape (keyCode 53)
        if event.keyCode == 53 {
            if isSearching {
                window.makeFirstResponder(window.contentView)
                store.isSearchFocused = false
                if !store.query.isEmpty {
                    store.query = ""
                }
                return nil
            }
            if !store.query.isEmpty {
                store.query = ""
                return nil
            }
            NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
            return nil
        }
        
        // 2. Focus Search: Command+F or Slash '/'
        if (isCommand && (chars == "f" || chars == "F" || event.keyCode == 3)) ||
           (!isSearching && chars == "/" && !isCommand && !isOption) {
            store.isSearchFocused = true
            return nil
        }
        
        // 3. Down Arrow (keyCode 125) when in search -> return to cards
        if event.keyCode == 125 && isSearching {
            window.makeFirstResponder(window.contentView)
            store.isSearchFocused = false
            return nil
        }
        
        // 4. Quick Paste 1-9 (top row or numpad)
        if let num = Int(chars), num >= 1 && num <= 9 {
            if !isSearching || isCommand {
                let targetIdx = num - 1
                if targetIdx < store.filteredClips.count {
                    let clip = store.filteredClips[targetIdx]
                    store.paste(clip: clip, asPlainText: isOption)
                }
                return nil
            }
        }
        
        // 5. If user is currently typing in search field, let remaining keys pass to NSTextField
        if isSearching {
            // Except Return key: paste active clip
            if event.keyCode == 36 || event.keyCode == 76 {
                if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                    let clip = store.filteredClips[store.activeIndex]
                    store.paste(clip: clip, asPlainText: isOption)
                    return nil
                }
            }
            return event
        }
        
        // --- Below this point: Field editor is NOT active ---
        
        // 6. Return / Enter (keyCode 36, 76)
        if event.keyCode == 36 || event.keyCode == 76 {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                store.paste(clip: clip, asPlainText: isOption)
                return nil
            }
        }
        
        // 7. Left Arrow (keyCode 123)
        if event.keyCode == 123 {
            if store.activeIndex > 0 {
                store.activeIndex -= 1
                scrollTarget = ScrollTarget(index: store.activeIndex)
            }
            return nil
        }
        
        // 8. Right Arrow (keyCode 124)
        if event.keyCode == 124 {
            if store.activeIndex < store.filteredClips.count - 1 {
                store.activeIndex += 1
                scrollTarget = ScrollTarget(index: store.activeIndex)
            }
            return nil
        }
        
        // 9. Space (keyCode 49) or 'P' / 'p' (keyCode 35) -> Quick Look Preview
        if event.keyCode == 49 || (!isCommand && (chars == "p" || chars == "P")) {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                NotificationCenter.default.post(name: .openPreviewWindow, object: clip)
                return nil
            }
        }
        
        // 10. 'E' / 'e' (keyCode 14) -> Edit Clip
        if !isCommand && (chars == "e" || chars == "E" || event.keyCode == 14) {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                if clip.type != .image {
                    NotificationCenter.default.post(name: .openEditWindow, object: clip)
                    return nil
                }
            }
        }
        
        // 11. Command + Delete (keyCode 51)
        if isCommand && event.keyCode == 51 {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                store.deleteClip(clip.id)
                return nil
            }
        }
        
        // 12. 'Q' / 'q' (keyCode 12) -> Add to or remove from Paste Queue
        let hasNoSpecialModifiers = event.modifierFlags.intersection([.command, .option, .control]).isEmpty
        if hasNoSpecialModifiers && (chars == "q" || chars == "Q" || event.keyCode == 12) {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                if PasteQueueManager.shared.contains(clipId: clip.id) {
                    PasteQueueManager.shared.remove(clipId: clip.id)
                } else {
                    PasteQueueManager.shared.enqueue(clip: clip)
                }
                return nil
            }
        }
        
        return event
    }
    
    // MARK: - Header & Footer
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Brand Logo
            HStack(spacing: 7) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("LibrePaste")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.leading, 8)
            
            // Type Filter
            TypeFilterView(selection: $store.filter)
            
            Spacer()
            
            // Search Bar
            SearchBarView(text: $store.query, isFocused: $store.isSearchFocused) {
                store.query = ""
            }
            
            // Pause / Incognito Toggle
            Button(action: { store.togglePause() }) {
                HStack(spacing: 4) {
                    Image(systemName: store.isPaused ? "shield.slash.fill" : "shield.fill")
                        .font(.system(size: 12))
                    if store.isPaused {
                        Text("Paused")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundStyle(store.isPaused ? Color.orange : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(store.isPaused ? Color.orange.opacity(0.14) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help(store.isPaused ? "Resume Clipboard Watcher" : "Pause Clipboard Watcher (Incognito)")
            
            // Settings Button
            Button(action: {
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Open Settings")
            
            // Clear All Button
            Button(action: { store.clearAll() }) {
                Text("Clear All")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Clear All Unpinned Clips")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private var queueControlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Paste Queue")
                    .font(.system(size: 13, weight: .bold))
                
                let count = PasteQueueManager.shared.items.count
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            // FIFO / LIFO toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    PasteQueueManager.shared.order = (PasteQueueManager.shared.order == .fifo) ? .lifo : .fifo
                    PasteQueueManager.shared.saveQueueToSettings()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text(PasteQueueManager.shared.order.shortName)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Toggle Queue Order (FIFO / LIFO)")
            
            // Collect Mode (REC)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    PasteQueueManager.shared.toggleCollectMode()
                }
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(PasteQueueManager.shared.isCollectModeActive ? Color.red : Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text("Collect Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PasteQueueManager.shared.isCollectModeActive ? Color.red : .primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PasteQueueManager.shared.isCollectModeActive ? Color.red.opacity(0.12) : Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("When active, all copied clips are automatically added to the queue")
            
            Spacer()
            
            // Start Sequential Paste / Paste Next
            Button(action: {
                NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    PasteQueueManager.shared.pasteNext()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Paste Next (⌥⌘V)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PasteQueueManager.shared.items.isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(PasteQueueManager.shared.items.isEmpty)
            
            // Open Mini HUD
            Button(action: {
                PasteQueueManager.shared.showHUD()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "pip")
                        .font(.system(size: 10))
                    Text("Floating HUD")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Show Floating Mini Queue HUD")
            
            // Clear Queue
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    PasteQueueManager.shared.clear()
                    store.reloadClips()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(PasteQueueManager.shared.items.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
    
    private var footerBar: some View {
        HStack(spacing: 16) {
            shortcutHint("1-9", "Quick Paste")
            shortcutHint("← →", "Navigate")
            shortcutHint("↵", "Paste")
            shortcutHint("⌥↵", "Plain Text")
            shortcutHint("Space", "Preview")
            shortcutHint("Q", "Queue")
            shortcutHint("⌘F", "Search")
            shortcutHint("E", "Edit")
            shortcutHint("⌘⌫", "Delete")
            shortcutHint("Esc", "Hide")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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

extension Notification.Name {
    public static let openSettingsWindow = Notification.Name("openSettingsWindow")
    public static let openPreviewWindow = Notification.Name("openPreviewWindow")
    public static let closePreviewWindow = Notification.Name("closePreviewWindow")
    public static let openEditWindow = Notification.Name("openEditWindow")
    public static let closeEditWindow = Notification.Name("closeEditWindow")
}
