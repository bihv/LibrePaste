//
//  ClipboardView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

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
                // Header Bar (Adaptive ViewThatFits)
                headerBar
                
                Divider()
                    .opacity(0.55)
                
                // Body Content (Sidebar + Horizontal Cards / Vertical List)
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
                        .opacity(0.55)
                    
                    VStack(spacing: 0) {
                        if store.isQueueSelected {
                            queueControlBar
                            Divider()
                                .opacity(0.55)
                        }
                        
                        ClipListView(
                            clips: store.filteredClips,
                            pinboards: store.pinboards,
                            activeIndex: store.activeIndex,
                            layoutStyle: store.clipLayoutStyle,
                            showAppIcons: store.compactShowAppIcons,
                            showShortcuts: store.compactShowShortcuts,
                            previewLines: store.compactPreviewLines,
                            scrollTarget: scrollTarget,
                            isRevealed: { store.isRevealed(clipId: $0) },
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
                            onToggleReveal: { clip in
                                store.toggleReveal(clip: clip)
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
                    .opacity(0.55)
                
                // Footer Shortcuts (Adaptive ViewThatFits)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.88)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        )
        .preferredColorScheme(store.appAppearance.colorScheme)
        .onAppear {
            if store.windowPresentationMode == .menuBarPopover || store.windowPresentationMode == .atCursor || store.clipLayoutStyle == .compactList {
                isSidebarCollapsed = true
            }
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
            if store.windowPresentationMode == .menuBarPopover || store.windowPresentationMode == .atCursor || store.clipLayoutStyle == .compactList {
                isSidebarCollapsed = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayModeChanged)) { _ in
            if store.windowPresentationMode == .menuBarPopover || store.windowPresentationMode == .atCursor || store.clipLayoutStyle == .compactList {
                isSidebarCollapsed = true
            }
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
        
        // 7. Arrow Navigation (Left/Up = previous, Right/Down = next)
        if event.keyCode == 123 || event.keyCode == 126 { // Left or Up
            if store.activeIndex > 0 {
                store.activeIndex -= 1
                scrollTarget = ScrollTarget(index: store.activeIndex)
            }
            return nil
        }
        
        if event.keyCode == 124 || event.keyCode == 125 { // Right or Down
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
        ViewThatFits(in: .horizontal) {
            wideHeaderBar
            mediumHeaderBar
            compactHeaderBar
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
    
    private var wideHeaderBar: some View {
        HStack(spacing: 8) {
            brandLogo(showText: true)
            WindowDragGripView()
                .frame(width: 18, height: 22)
            TypeFilterView(selection: $store.filter, isCompact: false)
            Spacer(minLength: 8)
            searchBar(minWidth: 180, maxWidth: 320)
            layoutToggleButton
            pauseToggleButton(showText: true)
            settingsButton
            clearAllButton(isCompact: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var mediumHeaderBar: some View {
        HStack(spacing: 6) {
            brandLogo(showText: true)
            WindowDragGripView()
                .frame(width: 18, height: 22)
            TypeFilterView(selection: $store.filter, isCompact: true)
            Spacer(minLength: 6)
            searchBar(minWidth: 160, maxWidth: 260)
            layoutToggleButton
            pauseToggleButton(showText: false)
            settingsButton
            clearAllButton(isCompact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var compactHeaderBar: some View {
        HStack(spacing: 4) {
            brandLogo(showText: false)
            WindowDragGripView()
                .frame(width: 18, height: 22)
            TypeFilterView(selection: $store.filter, isCompact: true)
            Spacer(minLength: 4)
            searchBar(minWidth: 140, maxWidth: 200)
            layoutToggleButton
            pauseToggleButton(showText: false)
            settingsButton
            clearAllButton(isCompact: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func brandLogo(showText: Bool) -> some View {
        HStack(spacing: 6) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            if showText {
                Text("LibrePaste")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private func searchBar(minWidth: CGFloat, maxWidth: CGFloat) -> some View {
        SearchBarView(text: $store.query, isFocused: $store.isSearchFocused) {
            store.query = ""
        }
        .frame(minWidth: minWidth, maxWidth: maxWidth)
    }
    
    private var layoutToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                store.toggleClipLayoutStyle()
            }
        }) {
            Image(systemName: store.clipLayoutStyle == .cards ? "list.bullet" : "rectangle.grid.1x2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.85))
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(store.clipLayoutStyle == .cards ? L10n.tr("Vertical Compact List") : L10n.tr("Horizontal Cards"))
    }
    
    private func pauseToggleButton(showText: Bool) -> some View {
        Button(action: { store.togglePause() }) {
            HStack(spacing: 4) {
                Image(systemName: store.isPaused ? "shield.slash.fill" : "shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                if store.isPaused && showText {
                    Text(L10n.tr("Paused"))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(store.isPaused ? Color.orange : Color.primary.opacity(0.85))
            .padding(.horizontal, (store.isPaused && showText) ? 8 : 6)
            .padding(.vertical, 5.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(store.isPaused ? Color.orange.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(store.isPaused ? Color.orange.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(store.isPaused ? L10n.tr("Resume Watcher") : L10n.tr("Pause Watcher"))
    }
    
    private var settingsButton: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.85))
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
        })
        .help(L10n.tr("Settings..."))
    }

    
    private func clearAllButton(isCompact: Bool) -> some View {
        Button(action: { store.clearAll() }) {
            if isCompact {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Text(L10n.tr("Clear History"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(.plain)
        .help(L10n.tr("Clear History"))
    }
    
    private var queueControlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(L10n.tr("Paste Queue"))
                    .font(.system(size: 13, weight: .bold))
                
                let count = PasteQueueManager.shared.items.count
                Text(L10n.tr("%lld items", Int64(count)))
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
            .help(L10n.tr("Toggle Queue Order (FIFO / LIFO)"))
            
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
                    Text(L10n.tr("Collect Mode"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PasteQueueManager.shared.isCollectModeActive ? Color.red : .primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PasteQueueManager.shared.isCollectModeActive ? Color.red.opacity(0.12) : Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("When active, all copied clips are automatically added to the queue"))
            
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
                    Text(L10n.tr("Paste Next (⌥⌘V)"))
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
                    Text(L10n.tr("Floating HUD"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Show Floating Mini Queue HUD"))
            
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
                    Text(L10n.tr("Clear"))
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
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        ViewThatFits(in: .horizontal) {
            wideFooterBar
            mediumFooterBar
            compactFooterBar
        }
    }
    
    private var wideFooterBar: some View {
        HStack(spacing: 12) {
            shortcutHint("1-9", "Quick Paste")
            shortcutHint(store.clipLayoutStyle == .compactList ? "↑ ↓" : "← →", "Navigate")
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
    
    private var mediumFooterBar: some View {
        HStack(spacing: 10) {
            shortcutHint("1-9", "Quick Paste")
            shortcutHint(store.clipLayoutStyle == .compactList ? "↑ ↓" : "← →", "Navigate")
            shortcutHint("↵", "Paste")
            shortcutHint("⌥↵", "Plain")
            shortcutHint("Space", "Preview")
            shortcutHint("⌘F", "Search")
            shortcutHint("Esc", "Hide")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private var compactFooterBar: some View {
        HStack(spacing: 8) {
            shortcutHint("1-9", "Paste")
            shortcutHint(store.clipLayoutStyle == .compactList ? "↑ ↓" : "← →", "Nav")
            shortcutHint("↵", "Paste")
            shortcutHint("Space", "Preview")
            shortcutHint("Esc", "Hide")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.85))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5)
                        .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
            Text(L10n.tr(label))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

extension Notification.Name {
    public static let openSettingsWindow = Notification.Name("openSettingsWindow")
    public static let openPreviewWindow = Notification.Name("openPreviewWindow")
    public static let closePreviewWindow = Notification.Name("closePreviewWindow")
    public static let openEditWindow = Notification.Name("openEditWindow")
    public static let closeEditWindow = Notification.Name("closeEditWindow")
}
