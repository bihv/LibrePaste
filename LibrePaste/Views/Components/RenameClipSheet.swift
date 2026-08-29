//
//  RenameClipSheet.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct RenameClipSheet: View {
    public let clip: ClipRecord
    public let onSave: (String?) -> Void
    public let onCancel: () -> Void
    
    @State private var name: String
    @FocusState private var isFocused: Bool
    
    public init(
        clip: ClipRecord,
        onSave: @escaping (String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        self._name = State(initialValue: clip.title ?? "")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Section
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                
                Text(L10n.tr("Rename Clip"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            // Clip Context Summary Card
            HStack(spacing: 12) {
                if clip.type == .image, let path = clip.imagePath {
                    ClipThumbnailView(imagePath: path, previewText: clip.preview)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill((clip.isSensitive ? (clip.sensitiveType?.themeColor ?? .orange) : clip.type.themeColor).opacity(0.12))
                        
                        Image(systemName: clip.isSensitive ? (clip.sensitiveType?.iconName ?? "lock.shield.fill") : clip.type.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(clip.isSensitive ? (clip.sensitiveType?.themeColor ?? .orange) : clip.type.themeColor)
                    }
                    .frame(width: 38, height: 38)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let src = clip.sourceName, !src.isEmpty {
                            Text(src)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        Text(clip.type.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text(clip.renderedPlainText(isRevealed: false))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
            
            // Name Input Field Section
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("Custom Name"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    TextField(L10n.tr("Enter clip name..."), text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .focused($isFocused)
                        .onSubmit {
                            handleSave()
                        }
                    
                    if !name.isEmpty {
                        Button(action: { name = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.tr("Clear Name"))
                        .accessibilityLabel(L10n.tr("Clear Name"))
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if let customTitle = clip.title, !customTitle.isEmpty {
                    Button(L10n.tr("Reset to Default")) {
                        onSave(nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(L10n.tr("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button(L10n.tr("Save")) {
                    handleSave()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
    }
    
    private func handleSave() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmed.isEmpty ? nil : trimmed)
    }
}
