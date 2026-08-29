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
    
    private var detectedColor: DetectedColorInfo? {
        guard !clip.isSensitive || isRevealed else { return nil }
        guard clip.type == .text || clip.type == .richtext else { return nil }
        return ColorCodeHelper.shared.detectColor(in: plainTextContent)
    }
    
    private var isColor: Bool {
        detectedColor != nil
    }
    
    private var prettyJSON: String? {
        JSONHelper.formatJSON(clip.content)
    }
    
    private var isJSON: Bool {
        prettyJSON != nil
    }
    
    private var isURL: Bool {
        clip.parsedLinkURL != nil
    }
    
    private var parsedURL: URL? {
        clip.parsedLinkURL
    }
    
    private var plainTextContent: String {
        if clip.isSensitive && !isRevealed {
            return clip.renderedPlainText(isRevealed: false)
        }
        if let rich = richAttributedString {
            return rich.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clip.renderedPlainText(isRevealed: isRevealed)
    }
    
    private var renderedContentText: String {
        if clip.isSensitive && !isRevealed {
            return clip.renderedPlainText(isRevealed: false)
        }
        if isJSON, let pretty = prettyJSON {
            return pretty
        }
        if let rich = richAttributedString {
            return rich.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if isURL {
            return (parsedURL?.absoluteString ?? clip.content).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clip.renderedPlainText(isRevealed: isRevealed)
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
                Text(L10n.tr("Sensitive Data Protected: %@", clip.customRuleName ?? clip.sensitiveType?.displayName ?? L10n.tr("Secret")))
                    .font(.system(size: 12, weight: .semibold))
                Text(isRevealed ? L10n.tr("Content is temporarily unmasked on screen.") : L10n.tr("Content is masked to prevent visual exposure. Press Space or click Reveal."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: handleToggleReveal) {
                Label(isRevealed ? L10n.tr("Hide Secret") : L10n.tr("Reveal Secret"), systemImage: isRevealed ? "eye.slash" : "eye")
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
                let success = await SecurityManager.shared.authenticate(reason: L10n.tr("Authenticate to view sensitive data in Quick Look"))
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
                    Label(isRevealed ? L10n.tr("Hide") : L10n.tr("Reveal"), systemImage: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(isRevealed ? L10n.tr("Hide sensitive text") : L10n.tr("Reveal sensitive text (Space)"))
            }
            
            // Contextual Actions
            if clip.type == .image, let path = clip.imagePath {
                // Actual Size / Fit toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        imageActualSize.toggle()
                    }
                }) {
                    Label(imageActualSize ? L10n.tr("Fit") : "100%",
                          systemImage: imageActualSize ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(imageActualSize ? L10n.tr("Fit image to window") : L10n.tr("View image at 100% actual size"))
                
                // Open in Preview.app
                Button(action: {
                    openInPreviewApp(path: path)
                }) {
                    Label(L10n.tr("Preview"), systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Open in Preview.app"))
            } else if isURL, let url = parsedURL {
                Link(destination: url) {
                    Label(L10n.tr("Open"), systemImage: "arrow.up.right.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Open link in browser"))
            }
            
            // Edit Button
            if clip.type != .image {
                Button(action: {
                    NotificationCenter.default.post(name: .openEditWindow, object: clip)
                    onClose()
                }) {
                    Label(L10n.tr("Edit"), systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Edit clip content (E)"))
            }
            
            // Copy Button
            Button(action: copyCurrentContent) {
                Label(isCopied ? L10n.tr("Copied") : L10n.tr("Copy"), systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("Copy content to clipboard"))
            
            // Paste Button
            Button(action: onPaste) {
                Label(L10n.tr("Paste"), systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .help(L10n.tr("Paste into active app (Return)"))
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
            QuickLookLinkContent(url: parsedURL, content: parsedURL?.absoluteString ?? clip.content)
            
        case .richtext, .text:
            if clip.isSensitive && !isRevealed {
                QuickLookTextContent(text: plainTextContent)
            } else if let colorInfo = detectedColor {
                QuickLookColorContent(colorInfo: colorInfo)
            } else if isJSON {
                QuickLookJSONContent(jsonText: prettyJSON ?? clip.content)
            } else if isRichText {
                if let rich = richAttributedString {
                    RichTextView(attributedString: rich)
                } else {
                    QuickLookTextContent(text: plainTextContent)
                }
            } else if isURL {
                QuickLookLinkContent(url: parsedURL, content: parsedURL?.absoluteString ?? clip.content)
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
            if let colorInfo = detectedColor {
                HStack(spacing: 6) {
                    Text("RGB(\(colorInfo.r255), \(colorInfo.g255), \(colorInfo.b255))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(colorInfo.hslString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if colorInfo.alpha < 0.999 {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(L10n.tr("Opacity")): \(colorInfo.aPercent)%")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if clip.type == .image {
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
                let urlString = (parsedURL?.absoluteString ?? clip.content).trimmingCharacters(in: .whitespacesAndNewlines)
                if let host = parsedURL?.host {
                    Text(host)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                Text(L10n.tr("%lld characters", Int64(urlString.count)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                let text = renderedContentText
                let charCount = text.count
                let wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                
                Text(L10n.tr("%lld characters", Int64(charCount)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(L10n.tr("%lld words", Int64(wordCount)))
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
        if isColor { return L10n.tr("Color") }
        if isJSON { return "JSON" }
        if isRichText { return L10n.tr("Rich Text") }
        if isURL { return L10n.tr("Link") }
        return clip.type.displayName
    }
    
    private var detectedSystemImage: String {
        if isColor { return "paintpalette.fill" }
        if isJSON { return "curlybraces" }
        if isRichText { return "text.alignleft" }
        if isURL { return "link" }
        return clip.type.systemImage
    }
    
    private var detectedThemeColor: Color {
        if let colorInfo = detectedColor { return colorInfo.color }
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
                    // Favicon / Globe Icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        FaviconImageView(urlString: content, size: 30, fallbackSystemImage: "globe")
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
                            Label(L10n.tr("Open in Browser"), systemImage: "arrow.up.right.square")
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
                    Text(L10n.tr("No image data available"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Dedicated Color Quick Look Content

private struct QuickLookColorContent: View {
    let colorInfo: DetectedColorInfo
    @State private var copiedFormatKey: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Large Interactive Color Swatch Hero Card
                heroSwatchCard
                
                // 2. Color Format Rows (One-Click Copy with visual feedback)
                formatCardsGrid
                
                // 3. Channel Level Meters
                channelMetersSection
            }
            .padding(24)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var heroSwatchCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Checkerboard background for alpha transparency
            CheckerboardPatternView(size: 8)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            // Color Swatch Fill
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorInfo.color)
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(colorInfo.subtleBorderColor, lineWidth: 1)
                )
                .shadow(color: colorInfo.color.opacity(0.35), radius: 12, y: 4)
            
            // Text Overlays with Legibility Background Badge
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(colorInfo.hexString)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(colorInfo.contrastTextColor)
                        .shadow(color: Color.black.opacity(colorInfo.isDark ? 0.35 : 0.12), radius: 2)
                    
                    Text(colorInfo.rgbString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(colorInfo.contrastTextColor.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(colorInfo.isDark ? 0.35 : 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Spacer()
                
                HStack(spacing: 6) {
                    if colorInfo.alpha < 0.999 {
                        Text("\(L10n.tr("Opacity")): \(colorInfo.aPercent)%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorInfo.contrastTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(colorInfo.isDark ? 0.4 : 0.18))
                            .clipShape(Capsule())
                    }
                    
                    Text(colorInfo.format.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(colorInfo.contrastTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(colorInfo.isDark ? 0.4 : 0.18))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.tr("Color: %@, %@", colorInfo.hexString, colorInfo.rgbString))
    }
    
    private var formatCardsGrid: some View {
        VStack(spacing: 8) {
            formatRow(title: "HEX", value: colorInfo.hexString, key: "hex")
            formatRow(title: "RGB", value: colorInfo.rgbString, key: "rgb")
            formatRow(title: "HSL", value: colorInfo.hslString, key: "hsl")
            formatRow(title: "SwiftUI", value: colorInfo.swiftCodeString, key: "swift")
            formatRow(title: "AppKit (NSColor)", value: colorInfo.nsColorCodeString, key: "nscolor")
        }
    }
    
    private func formatRow(title: String, value: String, key: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                copyValue(value, key: key)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: copiedFormatKey == key ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(copiedFormatKey == key ? L10n.tr("Copied") : L10n.tr("Copy"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(copiedFormatKey == key ? .green : nil)
            .help(L10n.tr("Copy %@ to clipboard", value))
            .accessibilityLabel(L10n.tr("Copy %@ to clipboard", value))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var channelMetersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("Color Channels"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                channelBar(name: L10n.tr("Red"), value: colorInfo.r255, maxVal: 255, percent: colorInfo.red, color: .red)
                channelBar(name: L10n.tr("Green"), value: colorInfo.g255, maxVal: 255, percent: colorInfo.green, color: .green)
                channelBar(name: L10n.tr("Blue"), value: colorInfo.b255, maxVal: 255, percent: colorInfo.blue, color: .blue)
                channelBar(name: L10n.tr("Alpha"), value: colorInfo.aPercent, maxVal: 100, percent: colorInfo.alpha, color: .gray, isPercentOnly: true)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    private func channelBar(name: String, value: Int, maxVal: Int, percent: Double, color: Color, isPercentOnly: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(percent)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text(isPercentOnly ? "\(value)%" : "\(value)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 45, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(isPercentOnly ? "\(value)%" : "\(value)")")
    }
    
    private func copyValue(_ value: String, key: String) {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString(value, forType: .string)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedFormatKey = key
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.15)) {
                if copiedFormatKey == key {
                    copiedFormatKey = nil
                }
            }
        }
    }
}
