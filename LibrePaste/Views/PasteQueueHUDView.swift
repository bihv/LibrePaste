//
//  PasteQueueHUDView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

@MainActor
public struct PasteQueueHUDView: View {
    @Bindable public var manager: PasteQueueManager
    
    public init(manager: PasteQueueManager) {
        self.manager = manager
    }
    
    public init() {
        self.manager = .shared
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Bar
            headerBar
            
            // Content Preview Area
            if manager.items.isEmpty {
                emptyStateView
            } else {
                currentClipCardView
                
                if manager.items.count > 1 {
                    upcomingItemsBar
                }
            }
            
            // Footer Actions
            footerActionBar
        }
        .padding(14)
        .frame(width: FloatingQueuePanel.defaultWidth)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack(spacing: 8) {
            // Queue Icon & Title
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                
                Text(L10n.tr("Paste Queue"))
                    .font(.system(size: 12, weight: .bold))
            }
            
            // Order Tag (FIFO / LIFO)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    manager.order = (manager.order == .fifo) ? .lifo : .fifo
                    manager.saveQueueToSettings()
                }
            }) {
                Text(manager.order.shortName)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Click to toggle FIFO (First In First Out) or LIFO (Last In First Out)"))
            
            // Progress Indicator Badge
            if !manager.items.isEmpty {
                Text(L10n.tr("%lld of %lld", Int64(currentDisplayIndex), Int64(manager.items.count)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Collect Mode Toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    manager.toggleCollectMode()
                }
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.isCollectModeActive ? Color.red : Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                    
                    Text("REC")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(manager.isCollectModeActive ? Color.red : .secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(manager.isCollectModeActive ? Color.red.opacity(0.12) : Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(manager.isCollectModeActive ? L10n.tr("Collect Mode ON: All copied items are enqueued") : L10n.tr("Click to enable Collect Mode (auto-enqueue Cmd+C)"))
            
            // Close HUD Button
            Button(action: {
                manager.hideHUD()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Close Queue Overlay"))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            
            Text(L10n.tr("Queue is Empty"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(L10n.tr("Turn on REC or right-click clips in LibrePaste to add."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var currentClipCardView: some View {
        Group {
            if let nextItem = manager.peekNext() {
                let clip = nextItem.clip
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: clip.type.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(clip.type.themeColor)
                        
                        if let source = clip.sourceName, !source.isEmpty {
                            Text(source)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(clip.type.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(clip.relativeTimeFormatted)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Preview content
                    Text(cleanPreview(clip.preview))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }
    
    private var upcomingItemsBar: some View {
        let upcoming = upcomingClips
        return HStack(spacing: 6) {
            Text(L10n.tr("Next:"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Image(systemName: item.clip.type.systemImage)
                        .font(.system(size: 9))
                        .foregroundStyle(item.clip.type.themeColor)
                    
                    Text(cleanPreview(item.clip.preview))
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .frame(maxWidth: 80, alignment: .leading)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            
            if manager.items.count > 3 {
                Text("+\(manager.items.count - 3)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var footerActionBar: some View {
        HStack(spacing: 8) {
            // Paste Next Button
            Button(action: {
                manager.pasteNext()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.tr("Paste Next"))
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text("⌥⌘V")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(manager.items.isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(manager.items.isEmpty)
            
            // Skip Button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    manager.skip()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 9))
                    Text(L10n.tr("Skip"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(manager.items.isEmpty)
            .help(L10n.tr("Skip current item without pasting"))
            
            // Clear Button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    manager.clear()
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(manager.items.isEmpty)
            .help(L10n.tr("Clear entire queue"))
        }
    }
    
    // MARK: - Helpers
    
    private var currentDisplayIndex: Int {
        if manager.items.isEmpty { return 0 }
        return 1
    }
    
    private var upcomingClips: [PasteQueueItem] {
        guard manager.items.count > 1 else { return [] }
        if manager.order == .fifo {
            return Array(manager.items.dropFirst().prefix(2))
        } else {
            return Array(manager.items.dropLast().reversed().prefix(2))
        }
    }
    
    private func cleanPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty content" }
        return trimmed
    }
}
