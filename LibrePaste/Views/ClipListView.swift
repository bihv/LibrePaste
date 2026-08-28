//
//  ClipListView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct ScrollTarget: Equatable {
    public let index: Int
    public let id: UUID
    
    public init(index: Int) {
        self.index = index
        self.id = UUID()
    }
}

public struct ClipListView: View {
    public let clips: [ClipRecord]
    public let pinboards: [Pinboard]
    public let activeIndex: Int
    public let layoutStyle: ClipLayoutStyle
    public let showAppIcons: Bool
    public let showShortcuts: Bool
    public let previewLines: Int
    public let scrollTarget: ScrollTarget?
    public let isRevealed: ((Int64) -> Bool)?
    public let onSelect: (Int) -> Void
    public let onPaste: (ClipRecord) -> Void
    public let onPastePlain: (ClipRecord) -> Void
    public let onTogglePin: (ClipRecord) -> Void
    public let onToggleReveal: ((ClipRecord) -> Void)?
    public let onDelete: (Int64) -> Void
    public let onEdit: (ClipRecord) -> Void
    public let onPreview: (ClipRecord) -> Void
    public let onAddToPinboard: (Int64, Int64?) -> Void
    public let onEnqueue: ((ClipRecord) -> Void)?
    public let onRemoveFromQueue: ((ClipRecord) -> Void)?
    
    public init(
        clips: [ClipRecord],
        pinboards: [Pinboard],
        activeIndex: Int,
        layoutStyle: ClipLayoutStyle = .cards,
        showAppIcons: Bool = true,
        showShortcuts: Bool = true,
        previewLines: Int = 2,
        scrollTarget: ScrollTarget? = nil,
        isRevealed: ((Int64) -> Bool)? = nil,
        onSelect: @escaping (Int) -> Void,
        onPaste: @escaping (ClipRecord) -> Void,
        onPastePlain: @escaping (ClipRecord) -> Void,
        onTogglePin: @escaping (ClipRecord) -> Void,
        onToggleReveal: ((ClipRecord) -> Void)? = nil,
        onDelete: @escaping (Int64) -> Void,
        onEdit: @escaping (ClipRecord) -> Void,
        onPreview: @escaping (ClipRecord) -> Void,
        onAddToPinboard: @escaping (Int64, Int64?) -> Void,
        onEnqueue: ((ClipRecord) -> Void)? = nil,
        onRemoveFromQueue: ((ClipRecord) -> Void)? = nil
    ) {
        self.clips = clips
        self.pinboards = pinboards
        self.activeIndex = activeIndex
        self.layoutStyle = layoutStyle
        self.showAppIcons = showAppIcons
        self.showShortcuts = showShortcuts
        self.previewLines = previewLines
        self.scrollTarget = scrollTarget
        self.isRevealed = isRevealed
        self.onSelect = onSelect
        self.onPaste = onPaste
        self.onPastePlain = onPastePlain
        self.onTogglePin = onTogglePin
        self.onToggleReveal = onToggleReveal
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onPreview = onPreview
        self.onAddToPinboard = onAddToPinboard
        self.onEnqueue = onEnqueue
        self.onRemoveFromQueue = onRemoveFromQueue
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            Group {
                if layoutStyle == .compactList {
                    verticalCompactListView
                } else {
                    horizontalCardsView
                }
            }
            .overlay {
                if clips.isEmpty {
                    emptyStateView
                }
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target, target.index >= 0 && target.index < clips.count else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    let anchor: UnitPoint?
                    if layoutStyle == .cards {
                        anchor = target.index == 0 ? .leading : nil
                    } else {
                        anchor = target.index == 0 ? .top : nil
                    }
                    proxy.scrollTo(clips[target.index].id, anchor: anchor)
                }
            }
        }
    }
    
    // MARK: - Layout Views
    
    private var horizontalCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(zip(clips.indices, clips)), id: \.1.id) { index, clip in
                    ClipCardView(
                        clip: clip,
                        index: index,
                        isSelected: index == activeIndex,
                        isRevealed: isRevealed?(clip.id) ?? false,
                        pinboards: pinboards,
                        onAction: { action in
                            handleCardAction(action, clip: clip, index: index)
                        }
                    )
                    .id(clip.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var verticalCompactListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 3) {
                ForEach(Array(zip(clips.indices, clips)), id: \.1.id) { index, clip in
                    ClipCompactRowView(
                        clip: clip,
                        index: index,
                        isSelected: index == activeIndex,
                        isRevealed: isRevealed?(clip.id) ?? false,
                        showAppIcon: showAppIcons,
                        showShortcut: showShortcuts,
                        previewLines: previewLines,
                        pinboards: pinboards,
                        onAction: { action in
                            handleCardAction(action, clip: clip, index: index)
                        }
                    )
                    .id(clip.id)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
    
    private func handleCardAction(_ action: ClipAction, clip: ClipRecord, index: Int) {
        switch action {
        case .select:
            onSelect(index)
        case .paste:
            onPaste(clip)
        case .pastePlain:
            onPastePlain(clip)
        case .togglePin:
            onTogglePin(clip)
        case .toggleReveal:
            onToggleReveal?(clip)
        case .delete:
            onDelete(clip.id)
        case .edit:
            onEdit(clip)
        case .preview:
            onPreview(clip)
        case .addToPinboard(let pinboardId):
            onAddToPinboard(clip.id, pinboardId)
        case .enqueue:
            onEnqueue?(clip)
        case .removeFromQueue:
            onRemoveFromQueue?(clip)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("No Clips Found")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text("Copy anything (text, links, images) to see it here.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
