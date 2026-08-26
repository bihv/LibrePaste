//
//  ClipCardView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public enum ClipAction {
    case select
    case paste
    case pastePlain
    case togglePin
    case delete
    case edit
    case preview
    case addToPinboard(Int64?)
}

public struct ClipCardView: View {
    public let clip: ClipRecord
    public let index: Int
    public let isSelected: Bool
    public let pinboards: [Pinboard]
    public let onAction: (ClipAction) -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        clip: ClipRecord,
        index: Int,
        isSelected: Bool,
        pinboards: [Pinboard],
        onAction: @escaping (ClipAction) -> Void
    ) {
        self.clip = clip
        self.index = index
        self.isSelected = isSelected
        self.pinboards = pinboards
        self.onAction = onAction
    }
    
    // Backwards-compatible convenience initializer
    public init(
        clip: ClipRecord,
        index: Int,
        isSelected: Bool,
        pinboards: [Pinboard],
        onSelect: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onPastePlain: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onAddToPinboard: @escaping (Int64?) -> Void
    ) {
        self.clip = clip
        self.index = index
        self.isSelected = isSelected
        self.pinboards = pinboards
        self.onAction = { action in
            switch action {
            case .select: onSelect()
            case .paste: onPaste()
            case .pastePlain: onPastePlain()
            case .togglePin: onTogglePin()
            case .delete: onDelete()
            case .edit: onEdit()
            case .preview: onPreview()
            case .addToPinboard(let pId): onAddToPinboard(pId)
            }
        }
    }
    
    private var headerTheme: CardHeaderTheme {
        AppColorHelper.shared.theme(appName: clip.sourceName, bundleId: clip.sourceIcon)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Banner with App Color Theme
            ClipCardHeaderView(
                clip: clip,
                index: index,
                isHovered: isHovered,
                theme: headerTheme,
                onTogglePin: { onAction(.togglePin) }
            )
            
            // Content Preview Area & Footer
            VStack(alignment: .leading, spacing: 8) {
                // Content Preview Area
                VStack(alignment: .leading) {
                    switch clip.type {
                    case .image:
                        ClipThumbnailView(imagePath: clip.imagePath, previewText: clip.preview)
                    case .link:
                        linkContentView
                    case .text, .richtext:
                        textContentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Footer Info
                footerView
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 220, height: 250)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackgroundColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(isHovered ? 0.12 : 0.04),
            radius: isSelected ? 8 : (isHovered ? 6 : 2),
            y: isSelected ? 3 : 1
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
        .contextMenu {
            contextMenuItems
        }
        .help("Double-click or press ↵ to paste")
    }
    
    // MARK: - Subviews
    
    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor).opacity(0.85)
        #else
        return Color.secondary.opacity(0.15)
        #endif
    }
    
    private var displayPreviewText: String {
        if !clip.preview.isEmpty {
            return clip.preview
        }
        if clip.type == .richtext || (clip.content.contains("<") && clip.content.contains(">")) {
            let stripped = clip.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clip.content
    }
    
    private var textContentView: some View {
        Text(displayPreviewText)
            .font(.system(size: 12.5, weight: .regular, design: .default))
            .foregroundStyle(.primary)
            .lineSpacing(2.5)
            .multilineTextAlignment(.leading)
            .lineLimit(8)
            .truncationMode(.tail)
    }
    
    private var linkContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = URL(string: clip.content), let host = url.host {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                    Text(host)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Text(clip.content)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(5)
                .truncationMode(.middle)
        }
    }
    
    private var footerView: some View {
        HStack(alignment: .center) {
            if clip.type == .text || clip.type == .richtext {
                Text("\(clip.content.count) chars")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if let currentPinboard = pinboards.first(where: { $0.id == clip.pinboardId }) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(currentPinboard.swiftUIColor)
                        .frame(width: 6, height: 6)
                    Text(currentPinboard.name)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
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
        
        Button(role: .destructive, action: { onAction(.delete) }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Dedicated Header Subview

private struct ClipCardHeaderView: View {
    let clip: ClipRecord
    let index: Int
    let isHovered: Bool
    let theme: CardHeaderTheme
    let onTogglePin: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Shortcut badge (1-9)
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .frame(width: 18, height: 18)
                    .background(theme.shortcutBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(theme.shortcutBorder, lineWidth: 0.8)
                    )
            }
            
            // Source App Icon
            if let icon = AppColorHelper.shared.getAppIcon(bundleId: clip.sourceIcon, appName: clip.sourceName) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 19, height: 19)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 0.5)
            } else {
                let initial = (clip.sourceName?.first.map { String($0) } ?? "?").uppercased()
                Text(initial)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .frame(width: 19, height: 19)
                    .background(Color.white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                    )
            }
            
            // App Name & Relative Time
            VStack(alignment: .leading, spacing: 0.5) {
                Text((clip.sourceName?.isEmpty == false ? clip.sourceName : nil) ?? "Unknown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 0.5)
                    .lineLimit(1)
                
                Text(clip.relativeTimeFormatted)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textSubColor)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 2)
            
            // Type icon badge
            Image(systemName: clip.type.systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textColor.opacity(0.9))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2.5)
                .background(Color.black.opacity(0.18))
                .clipShape(Capsule())
            
            // Pin button
            Button(action: onTogglePin) {
                if clip.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                        .shadow(color: Color.orange.opacity(0.6), radius: 2)
                } else {
                    Image(systemName: "pin")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(isHovered ? 0.85 : 0.45))
                }
            }
            .buttonStyle(.plain)
            .help(clip.pinned ? "Unpin" : "Pin to Top")
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(theme.gradient)
        .overlay(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 0.75)
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 0.75)
            }
        )
    }
}
