//
//  SidebarView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct SidebarView: View {
    public let pinboards: [Pinboard]
    public let counts: [Int64: Int]
    public let selectedId: Int64?
    public let isQueueSelected: Bool
    public let queueCount: Int?
    public let onSelect: (Int64?) -> Void
    public let onSelectQueue: (() -> Void)?
    public let onCreate: (String, String) -> Void
    public let onUpdate: (Int64, String, String) -> Void
    public let onDelete: (Int64) -> Void
    public let onReorder: (([Int64]) -> Void)?
    public let onAssignClip: ((Int64, Int64?) -> Void)?
    public let onEnqueueClip: ((Int64) -> Void)?
    
    @Binding public var isCollapsed: Bool
    
    @State private var showingCreateSheet = false
    @State private var editingPinboard: Pinboard? = nil
    @State private var isAllClipsTargeted = false
    @State private var isQueueTargeted = false
    @State private var isBottomAreaTargeted = false
    @State private var reorderTarget: (id: Int64, isBottom: Bool)? = nil
    @State private var clipTargetId: Int64? = nil
    
    public init(
        pinboards: [Pinboard],
        counts: [Int64: Int],
        selectedId: Int64?,
        isQueueSelected: Bool = false,
        queueCount: Int? = nil,
        isCollapsed: Binding<Bool>,
        onSelect: @escaping (Int64?) -> Void,
        onSelectQueue: (() -> Void)? = nil,
        onCreate: @escaping (String, String) -> Void,
        onUpdate: @escaping (Int64, String, String) -> Void,
        onDelete: @escaping (Int64) -> Void,
        onReorder: (([Int64]) -> Void)? = nil,
        onAssignClip: ((Int64, Int64?) -> Void)? = nil,
        onEnqueueClip: ((Int64) -> Void)? = nil
    ) {
        self.pinboards = pinboards
        self.counts = counts
        self.selectedId = selectedId
        self.isQueueSelected = isQueueSelected
        self.queueCount = queueCount
        self._isCollapsed = isCollapsed
        self.onSelect = onSelect
        self.onSelectQueue = onSelectQueue
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onReorder = onReorder
        self.onAssignClip = onAssignClip
        self.onEnqueueClip = onEnqueueClip
    }
    
    private func handleReorder(draggingId: Int64, targetId: Int64, insertAfter: Bool) {
        reorderTarget = nil
        clipTargetId = nil
        isBottomAreaTargeted = false
        
        guard draggingId != targetId,
              let fromIndex = pinboards.firstIndex(where: { $0.id == draggingId }) else {
            return
        }
        var ids = pinboards.map(\.id)
        let item = ids.remove(at: fromIndex)
        guard let newTargetIndex = ids.firstIndex(of: targetId) else {
            return
        }
        let rawDestinationIndex = insertAfter ? newTargetIndex + 1 : newTargetIndex
        let destinationIndex = min(max(0, rawDestinationIndex), ids.count)
        ids.insert(item, at: destinationIndex)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            onReorder?(ids)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Toggle & Title
            headerSection
            
            // All History Item
            allHistoryItem
            
            // Paste Queue Item
            pasteQueueItem
            
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            
            // Pinboards List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(Array(pinboards.enumerated()), id: \.element.id) { index, pinboard in
                        PinboardItemRowView(
                            pinboard: pinboard,
                            isSelected: selectedId == pinboard.id,
                            count: counts[pinboard.id] ?? 0,
                            isCollapsed: isCollapsed,
                            reorderTarget: $reorderTarget,
                            clipTargetId: $clipTargetId,
                            onSelect: { onSelect(pinboard.id) },
                            onEdit: { editingPinboard = pinboard },
                            onDelete: { onDelete(pinboard.id) },
                            onMoveUp: index > 0 ? {
                                var ids = pinboards.map(\.id)
                                ids.swapAt(index, index - 1)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    onReorder?(ids)
                                }
                            } : nil,
                            onMoveDown: index < pinboards.count - 1 ? {
                                var ids = pinboards.map(\.id)
                                ids.swapAt(index, index + 1)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    onReorder?(ids)
                                }
                            } : nil,
                            onReorder: { draggingId, insertAfter in
                                handleReorder(draggingId: draggingId, targetId: pinboard.id, insertAfter: insertAfter)
                            },
                            onAssignClip: { clipId in
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                onAssignClip?(clipId, pinboard.id)
                            }
                        )
                    }
                    
                    if !pinboards.isEmpty {
                        Color.clear
                            .frame(height: 24)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .center) {
                                if isBottomAreaTargeted {
                                    ReorderInsertionLineView()
                                }
                            }
                            .onDrop(
                                of: [.json],
                                delegate: PinboardBottomDropDelegate(
                                    lastPinboardId: pinboards.last?.id,
                                    isTargeted: $isBottomAreaTargeted,
                                    reorderTarget: $reorderTarget,
                                    onReorder: { draggingId in
                                        guard let last = pinboards.last else { return }
                                        handleReorder(draggingId: draggingId, targetId: last.id, insertAfter: true)
                                    }
                                )
                            )
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(width: isCollapsed ? 48 : 170)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .sheet(isPresented: $showingCreateSheet) {
            PinboardFormSheet(
                initialName: "",
                initialColor: "#6366f1",
                title: L10n.tr("New Pinboard"),
                submitTitle: L10n.tr("Save"),
                onSave: { name, color in
                    onCreate(name, color)
                    showingCreateSheet = false
                },
                onCancel: {
                    showingCreateSheet = false
                }
            )
        }
        .sheet(item: $editingPinboard) { pb in
            PinboardFormSheet(
                initialName: pb.name,
                initialColor: pb.color,
                title: L10n.tr("Edit Pinboard"),
                submitTitle: L10n.tr("Save"),
                onSave: { name, color in
                    onUpdate(pb.id, name, color)
                    editingPinboard = nil
                },
                onCancel: {
                    editingPinboard = nil
                }
            )
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCollapsed.toggle()
                }
            }) {
                Image(systemName: isCollapsed ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? L10n.tr("Expand Sidebar") : L10n.tr("Collapse Sidebar"))
            
            if !isCollapsed {
                Text(L10n.tr("Pinboards"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.65))
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(4)
                        .background(Color.accentColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("New Pinboard"))
            }
        }
        .padding(.horizontal, isCollapsed ? 6 : 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var allHistoryItem: some View {
        let isAllSelected = selectedId == nil && !isQueueSelected
        return SidebarNavItem(
            icon: "clock",
            title: L10n.tr("All History"),
            badgeCount: nil,
            isSelected: isAllSelected,
            isTargeted: isAllClipsTargeted,
            isCollapsed: isCollapsed,
            helpText: L10n.tr("All Clips (drop card here to unpin)"),
            action: { onSelect(nil) }
        )
        .onDrop(
            of: [.json],
            delegate: AllClipsDropDelegate(
                isTargeted: $isAllClipsTargeted,
                reorderTarget: $reorderTarget,
                onAssignClip: { clipId in
                    onAssignClip?(clipId, nil)
                }
            )
        )
    }
    
    private var pasteQueueItem: some View {
        let count = queueCount ?? PasteQueueManager.shared.items.count
        return SidebarNavItem(
            icon: "list.bullet.clipboard",
            title: L10n.tr("Paste Queue"),
            badgeCount: count > 0 ? count : nil,
            isSelected: isQueueSelected,
            isTargeted: isQueueTargeted,
            isCollapsed: isCollapsed,
            helpText: L10n.tr("Paste Queue (drop cards here to enqueue)"),
            action: { onSelectQueue?() }
        )
        .onDrop(
            of: [.json],
            delegate: PasteQueueDropDelegate(
                isTargeted: $isQueueTargeted,
                reorderTarget: $reorderTarget,
                onEnqueueClip: { clipId in
                    onEnqueueClip?(clipId)
                }
            )
        )
    }
}

// MARK: - Reusable Sidebar Nav Item View

private struct SidebarNavItem: View {
    let icon: String
    let title: String
    let badgeCount: Int?
    let isSelected: Bool
    let isTargeted: Bool
    let isCollapsed: Bool
    let helpText: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    .frame(width: isCollapsed ? 20 : 16, height: isCollapsed ? 20 : 16)
                    .scaleEffect(isTargeted ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)
                
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let count = badgeCount, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .foregroundStyle(isTargeted ? Color.accentColor : (isSelected ? Color.accentColor : (isHovered ? Color.primary : Color.primary.opacity(0.85))))
            .padding(.horizontal, isCollapsed ? 6 : 8)
            .padding(.vertical, 6)
            .frame(maxWidth: isCollapsed ? 34 : .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isTargeted
                            ? Color.accentColor.opacity(0.24)
                            : (isSelected
                                ? Color.accentColor.opacity(0.16)
                                : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isTargeted
                            ? Color.accentColor
                            : (isSelected ? Color.accentColor.opacity(0.35) : (isHovered ? Color.primary.opacity(0.12) : Color.clear)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isCollapsed ? 4 : 6)
        .onHover { isHovered = $0 }
        .help(helpText)
    }
}

// MARK: - Reorder Insertion Line View

private struct ReorderInsertionLineView: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
        }
        .padding(.horizontal, 4)
        .allowsHitTesting(false)
    }
}

// MARK: - Pinboard Item Row View

private struct PinboardItemRowView: View {
    let pinboard: Pinboard
    let isSelected: Bool
    let count: Int
    let isCollapsed: Bool
    @Binding var reorderTarget: (id: Int64, isBottom: Bool)?
    @Binding var clipTargetId: Int64?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onReorder: (Int64, Bool) -> Void
    let onAssignClip: (Int64) -> Void
    
    @State private var isHovered = false
    
    private var showTopLine: Bool {
        reorderTarget?.id == pinboard.id && reorderTarget?.isBottom == false
    }
    
    private var showBottomLine: Bool {
        reorderTarget?.id == pinboard.id && reorderTarget?.isBottom == true
    }
    
    private var isClipDropTarget: Bool {
        clipTargetId == pinboard.id
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(pinboard.swiftUIColor)
                    .frame(width: 9, height: 9)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 9, height: 9)
            }
            .frame(width: isCollapsed ? 20 : 16, height: isCollapsed ? 20 : 16)
            .scaleEffect(isClipDropTarget ? 1.35 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isClipDropTarget)
            
            if !isCollapsed {
                Text(pinboard.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.9))
                    .lineLimit(1)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(.horizontal, isCollapsed ? 6 : 8)
        .padding(.vertical, 5)
        .frame(maxWidth: isCollapsed ? 34 : .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isClipDropTarget
                        ? pinboard.swiftUIColor.opacity(0.24)
                        : (isSelected
                            ? Color.accentColor.opacity(0.16)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isClipDropTarget
                        ? pinboard.swiftUIColor
                        : (isSelected ? Color.accentColor.opacity(0.35) : (isHovered ? Color.primary.opacity(0.12) : Color.clear)),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .top) {
            if showTopLine {
                ReorderInsertionLineView()
                    .offset(y: -1)
            }
        }
        .overlay(alignment: .bottom) {
            if showBottomLine {
                ReorderInsertionLineView()
                    .offset(y: 1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isClipDropTarget)
        .animation(.easeInOut(duration: 0.12), value: showTopLine)
        .animation(.easeInOut(duration: 0.12), value: showBottomLine)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pinboard.name)
        .accessibilityValue("\(count) items")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onSelect()
        }
        .onDrop(
            of: [.json],
            delegate: PinboardRowDropDelegate(
                pinboardId: pinboard.id,
                reorderTarget: $reorderTarget,
                clipTargetId: $clipTargetId,
                onReorder: onReorder,
                onAssignClip: onAssignClip
            )
        )
        .draggable(DragItemPayload(kind: .pinboard, id: pinboard.id)) {
            HStack(spacing: 6) {
                Circle()
                    .fill(pinboard.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text(pinboard.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .contextMenu {
            Button(L10n.tr("Edit Pinboard..."), action: onEdit)
            if onMoveUp != nil || onMoveDown != nil {
                Divider()
                if let onMoveUp {
                    Button(L10n.tr("Move Up"), action: onMoveUp)
                }
                if let onMoveDown {
                    Button(L10n.tr("Move Down"), action: onMoveDown)
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(L10n.tr("Delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - Drop Delegates

private struct PinboardRowDropDelegate: DropDelegate {
    private let rowMidpointY: CGFloat = 14
    let pinboardId: Int64
    @Binding var reorderTarget: (id: Int64, isBottom: Bool)?
    @Binding var clipTargetId: Int64?
    let onReorder: (Int64, Bool) -> Void
    let onAssignClip: (Int64) -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste" else {
            reorderTarget = nil
            clipTargetId = nil
            return DropProposal(operation: .forbidden)
        }
        
        switch payload.kind {
        case .pinboard:
            guard payload.id != pinboardId else {
                if reorderTarget?.id == pinboardId {
                    reorderTarget = nil
                }
                return DropProposal(operation: .forbidden)
            }
            let isBottom = info.location.y >= rowMidpointY
            reorderTarget = (id: pinboardId, isBottom: isBottom)
            clipTargetId = nil
            return DropProposal(operation: .move)
        case .clip:
            reorderTarget = nil
            clipTargetId = pinboardId
            return DropProposal(operation: .copy)
        }
    }
    
    func dropExited(info: DropInfo) {
        if reorderTarget?.id == pinboardId {
            reorderTarget = nil
        }
        if clipTargetId == pinboardId {
            clipTargetId = nil
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        reorderTarget = nil
        clipTargetId = nil
        defer {
            NSPasteboard(name: .drag).clearContents()
        }
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste" else {
            return false
        }
        switch payload.kind {
        case .pinboard:
            guard payload.id != pinboardId else { return false }
            let insertAfter = info.location.y >= rowMidpointY
            onReorder(payload.id, insertAfter)
            return true
        case .clip:
            onAssignClip(payload.id)
            return true
        }
    }
}

private struct PinboardBottomDropDelegate: DropDelegate {
    let lastPinboardId: Int64?
    @Binding var isTargeted: Bool
    @Binding var reorderTarget: (id: Int64, isBottom: Bool)?
    let onReorder: (Int64) -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        reorderTarget = nil
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .pinboard,
              let lastId = lastPinboardId,
              payload.id != lastId else {
            isTargeted = false
            return DropProposal(operation: .forbidden)
        }
        isTargeted = true
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        reorderTarget = nil
        defer {
            NSPasteboard(name: .drag).clearContents()
        }
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .pinboard,
              let lastId = lastPinboardId,
              payload.id != lastId else {
            return false
        }
        onReorder(payload.id)
        return true
    }
}

private struct AllClipsDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    @Binding var reorderTarget: (id: Int64, isBottom: Bool)?
    let onAssignClip: (Int64) -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        reorderTarget = nil
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .clip else {
            isTargeted = false
            return DropProposal(operation: .forbidden)
        }
        isTargeted = true
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        reorderTarget = nil
        defer {
            NSPasteboard(name: .drag).clearContents()
        }
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .clip else {
            return false
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        onAssignClip(payload.id)
        return true
    }
}

private struct PasteQueueDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    @Binding var reorderTarget: (id: Int64, isBottom: Bool)?
    let onEnqueueClip: (Int64) -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        reorderTarget = nil
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .clip else {
            isTargeted = false
            return DropProposal(operation: .forbidden)
        }
        isTargeted = true
        return DropProposal(operation: .copy)
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        reorderTarget = nil
        defer {
            NSPasteboard(name: .drag).clearContents()
        }
        guard let payload = DragItemPayload.currentDragPayload(),
              payload.app == "LibrePaste",
              payload.kind == .clip else {
            return false
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        onEnqueueClip(payload.id)
        return true
    }
}

// MARK: - Unified Pinboard Form Sheet

private struct PinboardFormSheet: View {
    let title: String
    let submitTitle: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var selectedColor: String
    
    private let colorPresets = [
        "#6366f1", "#ef4444", "#f97316", "#10b981", "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899"
    ]
    
    init(
        initialName: String,
        initialColor: String,
        title: String,
        submitTitle: String,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._name = State(initialValue: initialName)
        self._selectedColor = State(initialValue: initialColor)
        self.title = title
        self.submitTitle = submitTitle
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            
            TextField(L10n.tr("Pinboard name"), text: $name)
                .textFieldStyle(.roundedBorder)
            
            Text(L10n.tr("Color"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(colorPresets, id: \.self) { colorHex in
                    Circle()
                        .fill(Color(hex: colorHex) ?? Color.indigo)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: selectedColor == colorHex ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColor = colorHex
                        }
                }
            }
            
            HStack {
                Spacer()
                Button(L10n.tr("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button(submitTitle) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onSave(trimmed, selectedColor)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 300)
    }
}
