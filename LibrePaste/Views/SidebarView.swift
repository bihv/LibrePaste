//
//  SidebarView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import UniformTypeIdentifiers

public struct SidebarView: View {
    public let pinboards: [Pinboard]
    public let counts: [Int64: Int]
    public let selectedId: Int64?
    public let onSelect: (Int64?) -> Void
    public let onCreate: (String, String) -> Void
    public let onUpdate: (Int64, String, String) -> Void
    public let onDelete: (Int64) -> Void
    public let onReorder: (([Int64]) -> Void)?
    public let onAssignClip: ((Int64, Int64?) -> Void)?
    
    @Binding public var isCollapsed: Bool
    
    @State private var showingCreateSheet = false
    @State private var editingPinboard: Pinboard? = nil
    @State private var isAllClipsTargeted = false
    @State private var isBottomAreaTargeted = false
    @State private var reorderTarget: (id: Int64, isBottom: Bool)? = nil
    @State private var clipTargetId: Int64? = nil
    
    public init(
        pinboards: [Pinboard],
        counts: [Int64: Int],
        selectedId: Int64?,
        isCollapsed: Binding<Bool>,
        onSelect: @escaping (Int64?) -> Void,
        onCreate: @escaping (String, String) -> Void,
        onUpdate: @escaping (Int64, String, String) -> Void,
        onDelete: @escaping (Int64) -> Void,
        onReorder: (([Int64]) -> Void)? = nil,
        onAssignClip: ((Int64, Int64?) -> Void)? = nil
    ) {
        self.pinboards = pinboards
        self.counts = counts
        self.selectedId = selectedId
        self._isCollapsed = isCollapsed
        self.onSelect = onSelect
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onReorder = onReorder
        self.onAssignClip = onAssignClip
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
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
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
                                #if os(macOS)
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                #endif
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
        .background(Color.primary.opacity(0.02))
        .sheet(isPresented: $showingCreateSheet) {
            PinboardFormSheet(
                initialName: "",
                initialColor: "#6366f1",
                title: "New Pinboard",
                submitTitle: "Create",
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
                title: "Edit Pinboard",
                submitTitle: "Save",
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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand Sidebar" : "Collapse Sidebar")
            
            if !isCollapsed {
                Text("Pinboards")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("New Pinboard")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var allHistoryItem: some View {
        Button(action: { onSelect(nil) }) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .scaleEffect(isAllClipsTargeted ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isAllClipsTargeted)
                
                if !isCollapsed {
                    Text("All Clips")
                        .font(.system(size: 12, weight: selectedId == nil ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .foregroundStyle(isAllClipsTargeted ? Color.accentColor : (selectedId == nil ? Color.accentColor : Color.primary))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAllClipsTargeted ? Color.accentColor.opacity(0.24) : (selectedId == nil ? Color.accentColor.opacity(0.12) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isAllClipsTargeted ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .help("All Clips (drop card here to unpin)")
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
            Circle()
                .fill(pinboard.swiftUIColor)
                .frame(width: 8, height: 8)
                .frame(width: 16)
                .scaleEffect(isClipDropTarget ? 1.35 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isClipDropTarget)
            
            if !isCollapsed {
                Text(pinboard.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isClipDropTarget
                        ? pinboard.swiftUIColor.opacity(0.22)
                        : (isSelected
                            ? Color.accentColor.opacity(0.12)
                            : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isClipDropTarget
                        ? pinboard.swiftUIColor
                        : Color.clear,
                    lineWidth: 1.5
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
            Button("Edit Pinboard...", action: onEdit)
            if onMoveUp != nil || onMoveDown != nil {
                Divider()
                if let onMoveUp {
                    Button("Move Up", action: onMoveUp)
                }
                if let onMoveDown {
                    Button("Move Down", action: onMoveDown)
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
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
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
        onAssignClip(payload.id)
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
            
            TextField("Pinboard name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            Text("Color")
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
                Button("Cancel", action: onCancel)
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
