//
//  QuickLookPreviewView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct QuickLookPreviewView: View {
    public let clip: ClipRecord
    public let onPaste: () -> Void
    public let onClose: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var richAttributedString: NSAttributedString?
    @State private var imageActualSize: Bool = false
    @State private var isCopied: Bool = false
    @State private var isRevealed: Bool = false
    @FocusState private var isViewFocused: Bool
    
    public init(clip: ClipRecord, onPaste: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.clip = clip
        self.onPaste = onPaste
        self.onClose = onClose
    }
    
    // MARK: - Format Detection
    
    private var isRichText: Bool {
        clip.type == .richtext || clip.rtf != nil || (clip.content.contains("<") && clip.content.contains(">"))
    }
    
    private var prettyJSON: String? {
        JSONHelper.formatJSON(clip.content)
    }
    
    private var isJSON: Bool {
        prettyJSON != nil
    }
    
    private var isURL: Bool {
        clip.type == .link || (URL(string: clip.content.trimmingCharacters(in: .whitespacesAndNewlines))?.host != nil)
    }
    
    private var parsedURL: URL? {
        URL(string: clip.content.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private var plainTextContent: String {
        let cleanText = RichTextHelper.stripHTML(clip.content)
        if clip.isSensitive && !isRevealed {
            if !clip.preview.isEmpty {
                return RichTextHelper.stripHTML(clip.preview)
            }
            return "••••••••••••••••"
        }
        if let rich = richAttributedString {
            return rich.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return !cleanText.isEmpty ? cleanText : clip.content
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
            
            // Sensitive Warning Banner
            if clip.isSensitive {
                sensitiveWarningBanner
            }
            
            // Content Area (Directly Formatted)
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer Bar
            footerBar
        }
        .frame(minWidth: 520, idealWidth: 680, maxWidth: .infinity, minHeight: 400, idealHeight: 520, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .focusEffectDisabled()
        .focused($isViewFocused)
        .onAppear {
            isViewFocused = true
        }
        .task(id: clip.id) {
            loadRichText(isDark: colorScheme == .dark)
        }
        .onChange(of: colorScheme) { _, newScheme in
            loadRichText(isDark: newScheme == .dark)
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: " ")) { _ in
            if clip.isSensitive {
                handleToggleReveal()
                return .handled
            }
            onClose()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "eE")) { _ in
            if clip.type != .image {
                NotificationCenter.default.post(name: .openEditWindow, object: clip)
                onClose()
                return .handled
            }
            return .ignored
        }
    }
    
    private func loadRichText(isDark: Bool) {
        guard isRichText else {
            richAttributedString = nil
            return
        }
        richAttributedString = RichTextHelper.parse(content: clip.content, rtf: clip.rtf, isDark: isDark)
    }
    
    // MARK: - Sensitive Warning Banner
    
    private var sensitiveWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: clip.sensitiveType?.iconName ?? "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(clip.sensitiveType?.themeColor ?? .orange)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Sensitive Data Protected: \(clip.customRuleName ?? clip.sensitiveType?.displayName ?? "Secret")")
                    .font(.system(size: 12, weight: .semibold))
                Text(isRevealed ? "Content is temporarily unmasked on screen." : "Content is masked to prevent visual exposure. Press Space or click Reveal.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: handleToggleReveal) {
                Label(isRevealed ? "Hide Secret" : "Reveal Secret", systemImage: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(clip.sensitiveType?.themeColor ?? .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background((clip.sensitiveType?.themeColor ?? .orange).opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle((clip.sensitiveType?.themeColor ?? .orange).opacity(0.2)),
            alignment: .bottom
        )
    }
    
    private func handleToggleReveal() {
        if isRevealed {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRevealed = false
            }
            return
        }
        
        let settings = DatabaseManager.shared.getAllSettings()
        let requireAuth = (settings["requireAuthToReveal"] ?? "false") == "true"
        if requireAuth {
            Task { @MainActor in
                let success = await SecurityManager.shared.authenticate(reason: "Authenticate to view sensitive data in Quick Look")
                if success {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.isRevealed = true
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                isRevealed = true
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Source App & Timestamp
            HStack(spacing: 8) {
                if let icon = AppColorHelper.shared.getAppIcon(bundleId: clip.sourceIcon, appName: clip.sourceName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5))
                } else {
                    Image(systemName: detectedSystemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(detectedThemeColor)
                }
                
                if let appName = clip.sourceName, !appName.isEmpty {
                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(detectedTypeDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                
                Text("•")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                
                Text(clip.relativeTimeFormatted)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Sensitive Reveal Button
            if clip.isSensitive {
                Button(action: handleToggleReveal) {
                    Label(isRevealed ? "Hide" : "Reveal", systemImage: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(isRevealed ? "Hide sensitive text" : "Reveal sensitive text (Space)")
            }
            
            // Contextual Actions
            if clip.type == .image, let path = clip.imagePath {
                // Actual Size / Fit toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        imageActualSize.toggle()
                    }
                }) {
                    Label(imageActualSize ? "Fit" : "100%",
                          systemImage: imageActualSize ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(imageActualSize ? "Fit image to window" : "View image at 100% actual size")
                
                // Open in Preview.app
                Button(action: {
                    openInPreviewApp(path: path)
                }) {
                    Label("Preview", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("Open in Preview.app")
            } else if isURL, let url = parsedURL {
                Link(destination: url) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("Open link in browser")
            }
            
            // Edit Button
            if clip.type != .image {
                Button(action: {
                    NotificationCenter.default.post(name: .openEditWindow, object: clip)
                    onClose()
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("Edit clip content (E)")
            }
            
            // Copy Button
            Button(action: copyCurrentContent) {
                Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .help("Copy content to clipboard")
            
            // Paste Button
            Button(action: onPaste) {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .help("Paste into active app (Return)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        switch clip.type {
        case .image:
            QuickLookImageContent(imagePath: clip.imagePath, imageActualSize: imageActualSize)
            
        case .link:
            QuickLookLinkContent(url: parsedURL, content: clip.content)
            
        case .richtext, .text:
            if clip.isSensitive && !isRevealed {
                QuickLookTextContent(text: plainTextContent)
            } else if isJSON {
                QuickLookJSONContent(jsonText: prettyJSON ?? clip.content)
            } else if isRichText {
                if let rich = richAttributedString {
                    RichTextView(attributedString: rich)
                } else {
                    QuickLookTextContent(text: plainTextContent)
                }
            } else if isURL {
                QuickLookLinkContent(url: parsedURL, content: clip.content)
            } else {
                QuickLookTextContent(text: plainTextContent)
            }
        }
    }
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        HStack(spacing: 12) {
            // Type badge
            HStack(spacing: 5) {
                Image(systemName: detectedSystemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(detectedThemeColor)
                Text(detectedTypeDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Contextual Metadata
            if clip.type == .image {
                if let path = clip.imagePath, let img = ThumbnailManager.shared.loadFullImage(from: path) {
                    let px = getImagePixelSize(img)
                    HStack(spacing: 6) {
                        Text("\(Int(px.width)) × \(Int(px.height)) px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                           let fileSize = attrs[.size] as? Int64 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if isURL {
                if let host = parsedURL?.host {
                    Text(host)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                Text("\(clip.content.count) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                let charCount = plainTextContent.count
                let wordCount = plainTextContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                
                Text("\(charCount) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(wordCount) words")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var detectedTypeDisplayName: String {
        if isJSON { return "JSON" }
        if isRichText { return "Rich Text" }
        if isURL { return "Link" }
        return clip.type.displayName
    }
    
    private var detectedSystemImage: String {
        if isJSON { return "curlybraces" }
        if isRichText { return "text.alignleft" }
        if isURL { return "link" }
        return clip.type.systemImage
    }
    
    private var detectedThemeColor: Color {
        if isJSON { return .yellow }
        if isRichText { return .orange }
        if isURL { return .green }
        return clip.type.themeColor
    }
    
    private func copyCurrentContent() {
        ClipboardWatcher.shared.markSelfWrite(hash: clip.hash)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch clip.type {
        case .image:
            if let path = clip.imagePath {
                if let data = ThumbnailManager.shared.loadDecryptedImageData(from: path) {
                    if let img = NSImage(data: data) {
                        pasteboard.writeObjects([img])
                    }
                    let fileUrl = URL(fileURLWithPath: path)
                    let ext = fileUrl.pathExtension.lowercased()
                    switch ext {
                    case "png":
                        pasteboard.setData(data, forType: .png)
                    case "jpg", "jpeg":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.jpeg"))
                    case "gif":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
                    case "heic":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.heic"))
                    case "webp":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("org.webmproject.webp"))
                    default:
                        pasteboard.setData(data, forType: .png)
                    }
                }
            }
        default:
            if clip.isSensitive && !isRevealed {
                pasteboard.setString(plainTextContent, forType: .string)
            } else if isRichText {
                if let rtf = clip.rtf, let rtfData = rtf.data(using: .utf8) {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                if clip.content.contains("<") && clip.content.contains(">"),
                   let htmlData = clip.content.data(using: .utf8) {
                    pasteboard.setData(htmlData, forType: .html)
                }
                pasteboard.setString(plainTextContent, forType: .string)
            } else if isJSON {
                pasteboard.setString(prettyJSON ?? clip.content, forType: .string)
            } else {
                pasteboard.setString(plainTextContent, forType: .string)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
    
    private func openInPreviewApp(path: String) {
        guard let data = ThumbnailManager.shared.loadDecryptedImageData(from: path) else { return }
        let originalURL = URL(fileURLWithPath: path)
        let ext = originalURL.pathExtension.isEmpty ? "png" : originalURL.pathExtension
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        
        let tempDir = ThumbnailManager.previewTempDir
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent("\(baseName).\(ext)")
        
        if (try? data.write(to: tempURL)) != nil {
            NSWorkspace.shared.open(tempURL)
        }
    }
    
    private func getImagePixelSize(_ image: NSImage) -> CGSize {
        if let rep = image.representations.first, rep.pixelsWide > 0 && rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }
}

// MARK: - Dedicated Subviews

private struct QuickLookTextContent: View {
    let text: String
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }
}

private struct QuickLookJSONContent: View {
    let jsonText: String
    
    var body: some View {
        ScrollView {
            Text(jsonText)
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }
}

private struct QuickLookLinkContent: View {
    let url: URL?
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    // Globe Icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 6)
                    
                    // Host / Domain
                    if let host = url?.host {
                        Text(host)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    // Full URL Text Box
                    Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12.5, design: .monospaced))
                        .lineLimit(8)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Open in Browser
                    if let targetUrl = url {
                        Link(destination: targetUrl) {
                            Label("Open in Browser", systemImage: "arrow.up.right.square")
                                .font(.system(size: 12.5, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
    }
}

private struct QuickLookImageContent: View {
    let imagePath: String?
    let imageActualSize: Bool
    
    var body: some View {
        Group {
            if let path = imagePath, let nsImage = ThumbnailManager.shared.loadFullImage(from: path) {
                GeometryReader { geo in
                    if imageActualSize {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: nsImage.size.width, height: nsImage.size.height)
                                .padding(20)
                                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .center)
                        }
                    } else {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(16)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No image data available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
