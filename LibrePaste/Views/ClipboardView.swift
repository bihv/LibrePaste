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
    @State private var isSearchFocused: Bool = false
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
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
                    isCollapsed: $isSidebarCollapsed,
                    onSelect: { pId in
                        store.selectedPinboardId = pId
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
                    }
                )
                
                Divider()
                    .opacity(0.3)
                
                ClipListView(
                    clips: store.filteredClips,
                    pinboards: store.pinboards,
                    activeIndex: store.activeIndex,
                    scrollTarget: scrollTarget,
                    onSelect: { idx in
                        store.activeIndex = idx
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
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .opacity(0.3)
            
            // Footer Shortcuts
            footerBar
        }
        .frame(height: FloatingPanel.panelHeight)
        .background(.ultraThinMaterial)
        .onKeyPress(.escape) {
            if isSearchFocused {
                isSearchFocused = false
                if !store.query.isEmpty {
                    store.query = ""
                }
                return .handled
            }
            if !store.query.isEmpty {
                store.query = ""
                return .handled
            }
            NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard !isSearchFocused else { return .ignored }
            if store.activeIndex > 0 {
                store.activeIndex -= 1
                scrollTarget = ScrollTarget(index: store.activeIndex)
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !isSearchFocused else { return .ignored }
            if store.activeIndex < store.filteredClips.count - 1 {
                store.activeIndex += 1
                scrollTarget = ScrollTarget(index: store.activeIndex)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                if NSEvent.modifierFlags.contains(.option) {
                    store.paste(clip: clip, asPlainText: true)
                } else {
                    store.paste(clip: clip)
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            let isCommandHeld = NSEvent.modifierFlags.contains(.command)
            // When search is focused, regular delete is handled by the textfield
            if isSearchFocused && !isCommandHeld {
                return .ignored
            }
            if isCommandHeld || !isSearchFocused {
                if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                    let clip = store.filteredClips[store.activeIndex]
                    store.deleteClip(clip.id)
                    return .handled
                }
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789")) { press in
            guard !isSearchFocused else { return .ignored }
            if let num = Int(press.characters), num >= 1 && num <= 9 {
                let targetIdx = num - 1
                if targetIdx < store.filteredClips.count {
                    let clip = store.filteredClips[targetIdx]
                    if NSEvent.modifierFlags.contains(.option) {
                        store.paste(clip: clip, asPlainText: true)
                    } else {
                        store.paste(clip: clip)
                    }
                    return .handled
                }
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: " ")) { _ in
            guard !isSearchFocused else { return .ignored }
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                NotificationCenter.default.post(name: .openPreviewWindow, object: clip)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "pP")) { _ in
            guard !isSearchFocused else { return .ignored }
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                NotificationCenter.default.post(name: .openPreviewWindow, object: clip)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "eE")) { _ in
            guard !isSearchFocused else { return .ignored }
            if store.activeIndex >= 0 && store.activeIndex < store.filteredClips.count {
                let clip = store.filteredClips[store.activeIndex]
                if clip.type != .image {
                    NotificationCenter.default.post(name: .openEditWindow, object: clip)
                    return .handled
                }
            }
            return .ignored
        }
        .onChange(of: store.filter) {
            scrollTarget = ScrollTarget(index: 0)
        }
        .onChange(of: store.query) {
            scrollTarget = ScrollTarget(index: 0)
        }
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
            SearchBarView(text: $store.query, isFocused: $isSearchFocused) {
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
    
    private var footerBar: some View {
        HStack(spacing: 16) {
            shortcutHint("1-9", "Quick Paste")
            shortcutHint("← →", "Navigate")
            shortcutHint("↵", "Paste")
            shortcutHint("⌥↵", "Plain Text")
            shortcutHint("Space", "Preview")
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
