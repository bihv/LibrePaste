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
    public let scrollTarget: ScrollTarget?
    public let onSelect: (Int) -> Void
    public let onPaste: (ClipRecord) -> Void
    public let onPastePlain: (ClipRecord) -> Void
    public let onTogglePin: (ClipRecord) -> Void
    public let onDelete: (Int64) -> Void
    public let onEdit: (ClipRecord) -> Void
    public let onPreview: (ClipRecord) -> Void
    public let onAddToPinboard: (Int64, Int64?) -> Void
    
    public init(
        clips: [ClipRecord],
        pinboards: [Pinboard],
        activeIndex: Int,
        scrollTarget: ScrollTarget? = nil,
        onSelect: @escaping (Int) -> Void,
        onPaste: @escaping (ClipRecord) -> Void,
        onPastePlain: @escaping (ClipRecord) -> Void,
        onTogglePin: @escaping (ClipRecord) -> Void,
        onDelete: @escaping (Int64) -> Void,
        onEdit: @escaping (ClipRecord) -> Void,
        onPreview: @escaping (ClipRecord) -> Void,
        onAddToPinboard: @escaping (Int64, Int64?) -> Void
    ) {
        self.clips = clips
        self.pinboards = pinboards
        self.activeIndex = activeIndex
        self.scrollTarget = scrollTarget
        self.onSelect = onSelect
        self.onPaste = onPaste
        self.onPastePlain = onPastePlain
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onPreview = onPreview
        self.onAddToPinboard = onAddToPinboard
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(zip(clips.indices, clips)), id: \.1.id) { index, clip in
                        ClipCardView(
                            clip: clip,
                            index: index,
                            isSelected: index == activeIndex,
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
            .overlay {
                if clips.isEmpty {
                    emptyStateView
                }
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target, target.index >= 0 && target.index < clips.count else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(clips[target.index].id, anchor: target.index == 0 ? .leading : nil)
                }
            }
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
        case .delete:
            onDelete(clip.id)
        case .edit:
            onEdit(clip)
        case .preview:
            onPreview(clip)
        case .addToPinboard(let pinboardId):
            onAddToPinboard(clip.id, pinboardId)
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
