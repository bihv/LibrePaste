//
//  EditClipView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public enum EditorMode: String, CaseIterable {
    case wysiwyg = "Visual"
    case source = "HTML"
}

public struct EditClipView: View {
    public let clip: ClipRecord
    public let onSave: (String, String, String?, String?) -> Void
    public let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: EditorMode
    @State private var editedTitle: String
    @State private var editedRawContent: String
    @State private var currentAttributedString: NSAttributedString
    @StateObject private var richController = RichTextEditorController()
    @State private var isMonospace: Bool = true
    @State private var isModified: Bool = false
    @FocusState private var isRawEditorFocused: Bool
    
    public init(
        clip: ClipRecord,
        onSave: @escaping (String, String, String?, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedTitle = State(initialValue: clip.title ?? "")
        self._editedRawContent = State(initialValue: clip.content)
        
        let isRich = clip.type == .richtext || clip.rtf != nil || (clip.content.contains("<") && clip.content.contains(">"))
        self._mode = State(initialValue: isRich ? .wysiwyg : .source)
        self._isMonospace = State(initialValue: clip.type == .link || JSONHelper.formatJSON(clip.content) != nil)
        
        let parsed = RichTextHelper.parse(content: clip.content, rtf: clip.rtf, isDark: true)
            ?? NSAttributedString(
                string: clip.content,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        self._currentAttributedString = State(initialValue: parsed)
    }
    
    // Convenience init for 3-parameter onSave
    public init(
        clip: ClipRecord,
        onSave: @escaping (String, String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            clip: clip,
            onSave: { content, preview, rtf, _ in onSave(content, preview, rtf) },
            onCancel: onCancel
        )
    }
    
    // Convenience init for 2-parameter onSave
    public init(
        clip: ClipRecord,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            clip: clip,
            onSave: { content, preview, _, _ in onSave(content, preview) },
            onCancel: onCancel
        )
    }
    
    private var isRichText: Bool {
        clip.type == .richtext || clip.rtf != nil || (clip.content.contains("<") && clip.content.contains(">"))
    }
    
    private var currentTextContent: String {
        if isRichText && mode == .wysiwyg {
            return currentAttributedString.string
        }
        return editedRawContent
    }
    
    private var wordCount: Int {
        currentTextContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    private var lineCount: Int {
        let lines = currentTextContent.split(separator: "\n", omittingEmptySubsequences: false)
        return max(1, lines.count)
    }
    
    private var canFormatJSON: Bool {
        !isRichText && JSONHelper.formatJSON(editedRawContent) != nil
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
            
            // Title / Name Bar
            titleBar
            
            Divider()
            
            // Formatting Toolbar for WYSIWYG Mode
            if isRichText && mode == .wysiwyg {
                formattingToolbar
                Divider()
            }
            
            // Editor Content Area
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer Bar
            footerBar
        }
        .frame(minWidth: 560, idealWidth: 720, maxWidth: .infinity, minHeight: 440, idealHeight: 540, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if isRichText {
                // Adapt to current color scheme
                let isDark = (colorScheme == .dark)
                if let parsed = RichTextHelper.parse(content: clip.content, rtf: clip.rtf, isDark: isDark) {
                    currentAttributedString = parsed
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isRawEditorFocused = true
                }
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            if isRichText && !isModified {
                let isDark = (newScheme == .dark)
                if let parsed = RichTextHelper.parse(content: clip.content, rtf: clip.rtf, isDark: isDark) {
                    currentAttributedString = parsed
                    richController.textView?.textStorage?.setAttributedString(parsed)
                }
            }
        }
        .background(
            // Hidden button to handle Cmd+Return for Save
            Button("") {
                handleSave()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(0)
        )
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Source App & Metadata
            HStack(spacing: 8) {
                if let icon = AppColorHelper.shared.getAppIcon(bundleId: clip.sourceIcon, appName: clip.sourceName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5))
                } else {
                    Image(systemName: clip.type.systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(clip.type.themeColor)
                }
                
                if let appName = clip.sourceName, !appName.isEmpty {
                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(clip.type.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                
                Text("•")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                
                Text(clip.relativeTimeFormatted)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                if isModified {
                    Text(L10n.tr("Modified"))
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Visual / HTML Mode Switcher for Rich Text
            if isRichText {
                Picker("", selection: Binding(
                    get: { mode },
                    set: { newMode in
                        switchMode(to: newMode)
                    }
                )) {
                    Text(L10n.tr("Visual")).tag(EditorMode.wysiwyg)
                    Text(L10n.tr("HTML")).tag(EditorMode.source)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
            
            // Format JSON (for JSON clips)
            if canFormatJSON {
                Button(action: formatJSONAction) {
                    Label(L10n.tr("Format JSON"), systemImage: "curlybraces")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Beautify JSON content"))
            }
            
            // Monospace Toggle (when in source/raw mode)
            if !isRichText || mode == .source {
                Button(action: { isMonospace.toggle() }) {
                    Image(systemName: isMonospace ? "textformat" : "character.cursor.ibeam")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(isMonospace ? L10n.tr("Switch to standard font") : L10n.tr("Switch to monospaced font"))
            }
            
            // Reset Button
            if isModified {
                Button(action: resetToOriginal) {
                    Label(L10n.tr("Reset"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Revert changes to original content"))
            }
            
            // Cancel Button (Esc)
            Button(L10n.tr("Cancel"), action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .help(L10n.tr("Discard changes (Esc)"))
            
            // Save Button (⌘S / ⌘Return)
            Button(action: handleSave) {
                Label(L10n.tr("Save"), systemImage: "checkmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
            .help(L10n.tr("Save changes (⌘S or ⌘Return)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Title Bar
    
    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            TextField(L10n.tr("Custom Clip Name (optional)"), text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .onChange(of: editedTitle) { _, _ in
                    isModified = true
                }
            
            if !editedTitle.isEmpty {
                Button(action: {
                    editedTitle = ""
                    isModified = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Clear Name"))
                .accessibilityLabel(L10n.tr("Clear Name"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
    
    // MARK: - Formatting Toolbar (WYSIWYG)
    
    private var formattingToolbar: some View {
        HStack(spacing: 6) {
            // Text Styles
            Group {
                Button(action: { richController.toggleBold() }) {
                    Image(systemName: "bold")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Bold (⌘B)"))
                
                Button(action: { richController.toggleItalic() }) {
                    Image(systemName: "italic")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Italic (⌘I)"))
                
                Button(action: { richController.toggleUnderline() }) {
                    Image(systemName: "underline")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Underline (⌘U)"))
                
                Button(action: { richController.toggleStrikethrough() }) {
                    Image(systemName: "strikethrough")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Strikethrough"))
            }
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 2)
            
            // Headings / Body Menu
            Menu {
                Button(L10n.tr("Heading (H1)")) {
                    richController.applyHeading()
                }
                Button(L10n.tr("Subheading (H2)")) {
                    richController.applySubheading()
                }
                Button(L10n.tr("Body Text")) {
                    richController.applyBody()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 11))
                    Text(L10n.tr("Style"))
                        .font(.system(size: 11))
                }
                .frame(height: 20)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .help(L10n.tr("Paragraph & Heading styles"))
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 2)
            
            // Lists & Formatting
            Button(action: { richController.toggleBulletList() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("Bullet list"))
            
            Button(action: { richController.clearFormatting() }) {
                Image(systemName: "clear")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("Clear formatting"))
            
            Spacer()
            
            // Undo / Redo
            Button(action: { richController.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.bordered)
            .disabled(!richController.canUndo)
            .help(L10n.tr("Undo (⌘Z)"))
            
            Button(action: { richController.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.bordered)
            .disabled(!richController.canRedo)
            .help(L10n.tr("Redo (⌘⇧Z)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        if isRichText && mode == .wysiwyg {
            RichTextWYSIWYGEditorView(
                attributedString: currentAttributedString,
                controller: richController,
                onTextChange: { newAttr in
                    currentAttributedString = newAttr
                    isModified = true
                }
            )
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        } else {
            TextEditor(text: Binding(
                get: { editedRawContent },
                set: { val in
                    editedRawContent = val
                    isModified = true
                }
            ))
            .font(isMonospace ? .system(size: 13, design: .monospaced) : .system(size: 13.5, design: .default))
            .lineSpacing(4)
            .focused($isRawEditorFocused)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .padding(12)
        }
    }
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        HStack(spacing: 12) {
            // Type badge
            HStack(spacing: 5) {
                Image(systemName: clip.type.systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(clip.type.themeColor)
                Text(clip.type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            // Mode indicator
            HStack(spacing: 4) {
                Image(systemName: isRichText && mode == .wysiwyg ? "pencil.and.outline" : "curlybraces")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(isRichText && mode == .wysiwyg ? L10n.tr("WYSIWYG Editor") : (isRichText ? L10n.tr("HTML Source") : L10n.tr("Plain Editor")))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Live stats
            Text(L10n.tr("%lld characters", currentTextContent.count))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text("•")
                .foregroundStyle(.tertiary)
            
            Text(L10n.tr("%lld words", wordCount))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text("•")
                .foregroundStyle(.tertiary)
            
            Text(L10n.tr("%lld lines", lineCount))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Mode Switching & Actions
    
    private func switchMode(to newMode: EditorMode) {
        guard newMode != mode else { return }
        
        if newMode == .source {
            // Switching from WYSIWYG to Source: export clean HTML
            editedRawContent = richController.exportHTML()
            mode = .source
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isRawEditorFocused = true
            }
        } else {
            // Switching from Source to WYSIWYG: re-parse HTML to attributed string
            let isDark = (colorScheme == .dark)
            if let parsed = RichTextHelper.parse(content: editedRawContent, rtf: nil, isDark: isDark) {
                currentAttributedString = parsed
                richController.textView?.textStorage?.setAttributedString(parsed)
            } else {
                let attr = NSAttributedString(
                    string: editedRawContent,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 14),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
                currentAttributedString = attr
                richController.textView?.textStorage?.setAttributedString(attr)
            }
            mode = .wysiwyg
        }
    }
    
    private func resetToOriginal() {
        editedTitle = clip.title ?? ""
        editedRawContent = clip.content
        let isDark = (colorScheme == .dark)
        let parsed = RichTextHelper.parse(content: clip.content, rtf: clip.rtf, isDark: isDark)
            ?? NSAttributedString(
                string: clip.content,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        currentAttributedString = parsed
        richController.textView?.textStorage?.setAttributedString(parsed)
        isModified = false
    }
    
    private func handleSave() {
        let cleanTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? nil : cleanTitle
        
        if isRichText && mode == .wysiwyg {
            let html = richController.exportHTML()
            let rtf = richController.exportRTF()
            let plain = richController.exportPlainText().trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = plain
            onSave(html.isEmpty ? plain : html, preview, rtf, finalTitle)
        } else {
            let preview = isRichText ? RichTextHelper.stripHTML(editedRawContent) : editedRawContent.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(editedRawContent, preview, nil, finalTitle)
        }
    }
    
    private func formatJSONAction() {
        if let pretty = JSONHelper.formatJSON(editedRawContent) {
            withAnimation(.easeInOut(duration: 0.15)) {
                editedRawContent = pretty
                isModified = true
            }
        }
    }
}
