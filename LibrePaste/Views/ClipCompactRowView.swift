//
//  ClipCompactRowView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct ClipCompactRowView: View {
    public let clip: ClipRecord
    public let index: Int
    public let isSelected: Bool
    public let isRevealed: Bool
    public let showAppIcon: Bool
    public let showShortcut: Bool
    public let previewLines: Int
    public let pinboards: [Pinboard]
    public let onAction: (ClipAction) -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        clip: ClipRecord,
        index: Int,
        isSelected: Bool,
        isRevealed: Bool = false,
        showAppIcon: Bool = true,
        showShortcut: Bool = true,
        previewLines: Int = 2,
        pinboards: [Pinboard],
        onAction: @escaping (ClipAction) -> Void
    ) {
        self.clip = clip
        self.index = index
        self.isSelected = isSelected
        self.isRevealed = isRevealed
        self.showAppIcon = showAppIcon
        self.showShortcut = showShortcut
        self.previewLines = previewLines
        self.pinboards = pinboards
        self.onAction = onAction
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. Shortcut Index Badge (1-9)
            if showShortcut {
                shortcutBadge
            }
            
            // 2. App Icon & Type Indicator
            leadingIconSection
            
            // 3. Content Preview & Metadata
            contentSection
            
            Spacer(minLength: 4)
            
            // 4. Trailing Badges & Hover Actions
            trailingSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, previewLines > 1 ? 6 : 5)
        .frame(maxWidth: .infinity, minHeight: previewLines > 1 ? 48 : 38)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.65) : (isHovered ? Color.primary.opacity(0.12) : Color.clear),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onAction(.select)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onAction(.paste)
            }
        )
        .clipCardDraggable(clip: clip)
        .contextMenu {
            contextMenuItems
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var shortcutBadge: some View {
        if index < 9 {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                )
        } else {
            Color.clear
                .frame(width: 18, height: 18)
        }
    }
    
    private var leadingIconSection: some View {
        HStack(spacing: 5) {
            // Source App Icon
            if showAppIcon {
                if let appIcon = AppColorHelper.shared.getAppIcon(bundleId: clip.sourceIcon, appName: clip.sourceName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
            }
            
            // Clip Type Badge Icon
            Image(systemName: clip.type.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(clip.type.themeColor)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(clip.type.themeColor.opacity(0.12))
                )
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Main Content Line
            HStack(spacing: 6) {
                if clip.type == .image {
                    imagePreviewRow
                } else {
                    textPreviewRow
                }
            }
            
            // Subtext / Metadata Line
            if previewLines > 1 {
                metadataRow
            }
        }
    }
    
    private var textPreviewRow: some View {
        HStack(spacing: 6) {
            if clip.isSensitive && !isRevealed {
                HStack(spacing: 4) {
                    Image(systemName: clip.sensitiveType?.iconName ?? "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(clip.sensitiveType?.themeColor ?? .orange)
                    Text(clip.customRuleName ?? clip.sensitiveType?.displayName ?? "Sensitive Data Masked")
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else if clip.type == .link, let url = URL(string: clip.content), let host = url.host {
                HStack(spacing: 4) {
                    Text(host)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    Text(displayPreviewText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text(displayPreviewText)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : Color.primary.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    private var imagePreviewRow: some View {
        HStack(spacing: 6) {
            ClipThumbnailView(imagePath: clip.imagePath, previewText: clip.preview)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            Text(clip.preview.isEmpty ? "Image" : clip.preview)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
    
    private var metadataRow: some View {
        HStack(spacing: 5) {
            // Character count / clip type info
            if clip.type == .text || clip.type == .richtext {
                Text("\(clip.content.count) chars")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else if clip.type == .link {
                Text("URL")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else if clip.type == .image {
                Text("Image")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            // Dot separator
            Text("•")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            
            // Relative time
            Text(clip.relativeTimeFormatted)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            
            // Pinboard tag if assigned
            if let currentPinboard = pinboards.first(where: { $0.id == clip.pinboardId }) {
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                
                HStack(spacing: 3) {
                    Circle()
                        .fill(currentPinboard.swiftUIColor)
                        .frame(width: 5, height: 5)
                    Text(currentPinboard.name)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var trailingSection: some View {
        HStack(spacing: 6) {
            // Badges
            if clip.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                    .help("Pinned to Top")
            }
            
            if PasteQueueManager.shared.contains(clipId: clip.id) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                    .help("In Paste Queue")
            }
            
            // Hover Quick Actions Toolbar
            if isHovered || isSelected {
                hoverActionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if previewLines == 1 {
                // In single line mode, display time on trailing if not hovered
                Text(clip.relativeTimeFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var hoverActionButtons: some View {
        HStack(spacing: 3) {
            // Direct Paste
            Button(action: { onAction(.paste) }) {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Paste into active app (↵)")
            
            // Quick Look Preview
            Button(action: { onAction(.preview) }) {
                Image(systemName: "eye")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.06))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Quick Look Preview (Space)")
            
            // Toggle Pin
            Button(action: { onAction(.togglePin) }) {
                Image(systemName: clip.pinned ? "pin.slash" : "pin")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.06))
                    .foregroundStyle(clip.pinned ? Color.orange : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help(clip.pinned ? "Unpin clip" : "Pin clip to top")
            
            // Toggle Reveal (if sensitive)
            if clip.isSensitive {
                Button(action: { onAction(.toggleReveal) }) {
                    Image(systemName: isRevealed ? "eye.slash" : "lock.open")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide sensitive content" : "Reveal sensitive content")
            }
            
            // Delete Clip
            Button(action: { onAction(.delete) }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Delete clip (⌘⌫)")
        }
    }
    
    // MARK: - Helpers & Context Menu
    
    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if isHovered {
            return Color.primary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private var displayPreviewText: String {
        let cleanText = RichTextHelper.stripHTML(clip.content)
        
        if clip.isSensitive && !isRevealed {
            if !clip.preview.isEmpty {
                return RichTextHelper.stripHTML(clip.preview)
            }
            return "••••••••••••••••"
        }
        if !clip.preview.isEmpty && !clip.isSensitive {
            return RichTextHelper.stripHTML(clip.preview)
        }
        return !cleanText.isEmpty ? cleanText : RichTextHelper.stripHTML(clip.preview)
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: { onAction(.paste) }) {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        
        if clip.type == .link || clip.type == .richtext {
            Button(action: { onAction(.pastePlain) }) {
                Label("Paste as Plain Text", systemImage: "text.alignleft")
            }
        }
        
        if clip.isSensitive {
            Button(action: { onAction(.toggleReveal) }) {
                Label(isRevealed ? "Hide Sensitive Content" : "Reveal Sensitive Content", systemImage: isRevealed ? "eye.slash" : "eye")
            }
        }
        
        Button(action: { onAction(.preview) }) {
            Label("Quick Look Preview", systemImage: "eye")
        }
        
        if clip.type != .image {
            Button(action: { onAction(.edit) }) {
                Label("Edit...", systemImage: "pencil")
            }
        }
        
        Divider()
        
        Menu("Pinboard") {
            if clip.pinboardId != nil {
                Button(action: { onAction(.addToPinboard(nil)) }) {
                    Label("Remove from Pinboard", systemImage: "xmark")
                }
                Divider()
            }
            
            if pinboards.isEmpty {
                Text("No Pinboards Available")
            } else {
                ForEach(pinboards) { pb in
                    Button(action: { onAction(.addToPinboard(pb.id)) }) {
                        HStack {
                            Text(pb.name)
                            if clip.pinboardId == pb.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        
        Button(action: { onAction(.togglePin) }) {
            Label(clip.pinned ? "Unpin" : "Pin to Top", systemImage: clip.pinned ? "pin.slash" : "pin")
        }
        
        Divider()
        
        let isInQueue = PasteQueueManager.shared.contains(clipId: clip.id)
        if isInQueue {
            Button(action: { onAction(.removeFromQueue) }) {
                Label("Remove from Paste Queue", systemImage: "minus.rectangle")
            }
        } else {
            Button(action: { onAction(.enqueue) }) {
                Label("Add to Paste Queue", systemImage: "list.bullet.clipboard")
            }
        }
        
        Divider()
        
        Button(role: .destructive, action: { onAction(.delete) }) {
            Label("Delete", systemImage: "trash")
        }
    }
}
