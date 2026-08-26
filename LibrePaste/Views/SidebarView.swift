//
//  SidebarView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct SidebarView: View {
    public let pinboards: [Pinboard]
    public let counts: [Int64: Int]
    public let selectedId: Int64?
    public let onSelect: (Int64?) -> Void
    public let onCreate: (String, String) -> Void
    public let onUpdate: (Int64, String, String) -> Void
    public let onDelete: (Int64) -> Void
    
    @Binding public var isCollapsed: Bool
    
    @State private var showingCreateSheet = false
    @State private var editingPinboard: Pinboard? = nil
    
    public init(
        pinboards: [Pinboard],
        counts: [Int64: Int],
        selectedId: Int64?,
        isCollapsed: Binding<Bool>,
        onSelect: @escaping (Int64?) -> Void,
        onCreate: @escaping (String, String) -> Void,
        onUpdate: @escaping (Int64, String, String) -> Void,
        onDelete: @escaping (Int64) -> Void
    ) {
        self.pinboards = pinboards
        self.counts = counts
        self.selectedId = selectedId
        self._isCollapsed = isCollapsed
        self.onSelect = onSelect
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onDelete = onDelete
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
                    ForEach(pinboards) { pinboard in
                        PinboardItemRowView(
                            pinboard: pinboard,
                            isSelected: selectedId == pinboard.id,
                            count: counts[pinboard.id] ?? 0,
                            isCollapsed: isCollapsed,
                            onSelect: { onSelect(pinboard.id) },
                            onEdit: { editingPinboard = pinboard },
                            onDelete: { onDelete(pinboard.id) }
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
                
                if !isCollapsed {
                    Text("All Clips")
                        .font(.system(size: 12, weight: selectedId == nil ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .foregroundStyle(selectedId == nil ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedId == nil ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .help("All Clips")
    }
}

// MARK: - Pinboard Item Row View

private struct PinboardItemRowView: View {
    let pinboard: Pinboard
    let isSelected: Bool
    let count: Int
    let isCollapsed: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(pinboard.swiftUIColor)
                    .frame(width: 8, height: 8)
                    .frame(width: 16)
                
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
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit Pinboard...", action: onEdit)
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
