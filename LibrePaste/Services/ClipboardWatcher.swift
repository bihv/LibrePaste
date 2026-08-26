//
//  ClipboardWatcher.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import UniformTypeIdentifiers

public final class ClipboardWatcher {
    public static let shared = ClipboardWatcher()
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastHash: String = ""
    private var selfWriteExpiry: Double = 0
    private var isPaused: Bool = false
    
    public var onClipAdded: ((ClipRecord, Bool) -> Void)?
    public var onPausedChanged: ((Bool) -> Void)?
    
    private let passwordManagerNames: Set<String> = [
        "1password",
        "keychain access",
        "passwords",
        "bitwarden",
        "keepassxc",
        "lastpass",
        "enpass",
        "dashlane",
        "nordpass",
        "proton pass",
        "roboform",
        "authpass",
        "keepass",
        "keepass2android"
    ]
    
    private let urlRegex = try? NSRegularExpression(
        pattern: "^(https?:\\/\\/|www\\.)[^\\s]+$",
        options: .caseInsensitive
    )
    
    private let richFormatRegex = try? NSRegularExpression(
        pattern: "<(b|strong|i|em|u|ins|s|strike|span|font|mark|sub|sup|small)\\b[^>]*>",
        options: .caseInsensitive
    )
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // MARK: - Control
    
    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func togglePause() -> Bool {
        isPaused.toggle()
        onPausedChanged?(isPaused)
        return isPaused
    }
    
    public func setPaused(_ paused: Bool) {
        isPaused = paused
        onPausedChanged?(isPaused)
    }
    
    public var paused: Bool {
        isPaused
    }
    
    public func markSelfWrite(hash: String) {
        lastHash = hash
        selfWriteExpiry = Date().timeIntervalSince1970 * 1000 + 1000 // 1 second window
    }
    
    // MARK: - Inspection
    
    private func checkPasteboard() {
        if isPaused { return }
        
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Check self-write window
        let now = Date().timeIntervalSince1970 * 1000
        if now < selfWriteExpiry {
            selfWriteExpiry = 0
            return
        }
        
        // Transient data check
        if isTransientData(pasteboard) {
            return
        }
        
        // Source app check
        let (sourceName, bundleId) = getEffectiveSourceApp()
        
        if isAppIgnored(sourceName: sourceName, bundleId: bundleId) {
            return
        }
        
        // Process content
        guard let clip = readClipboard(pasteboard: pasteboard, sourceName: sourceName, bundleId: bundleId) else {
            return
        }
        
        if clip.hash == lastHash {
            return
        }
        lastHash = clip.hash
        
        // Persist on background queue to keep Main Thread fluid
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (savedRecord, isNew) = DatabaseManager.shared.upsertClip(clip)
            DispatchQueue.main.async {
                self?.onClipAdded?(savedRecord, isNew)
            }
        }
    }
    
    // MARK: - Source App Resolution
    
    private func getEffectiveSourceApp() -> (name: String?, bundleId: String?) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        
        // 1. If frontmost is not LibrePaste, return it directly
        if let frontmost = frontmost, frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return (frontmost.localizedName, frontmost.bundleIdentifier)
        }
        
        // 2. If frontmost is LibrePaste, check for an active regular GUI app
        if let activeRegular = NSWorkspace.shared.runningApplications.first(where: {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.isActive
        }) {
            return (activeRegular.localizedName, activeRegular.bundleIdentifier)
        }
        
        // 3. Fallback to store's remembered lastActiveAppBundleId
        if let lastId = AppDelegate.shared?.store.lastActiveAppBundleId,
           lastId != Bundle.main.bundleIdentifier {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: lastId).first {
                return (running.localizedName, running.bundleIdentifier)
            }
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: lastId),
               let bundle = Bundle(url: appUrl) {
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? FileManager.default.displayName(atPath: appUrl.path)
                return (name, lastId)
            }
            return (nil, lastId)
        }
        
        return (nil, nil)
    }
    
    private func isTransientData(_ pasteboard: NSPasteboard) -> Bool {
        let ignoreTransient = DatabaseManager.shared.getSetting("ignoreTransient")
        if ignoreTransient == "false" { return false }
        
        let transientTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
            NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
        ]
        
        if let types = pasteboard.types {
            for t in types {
                if transientTypes.contains(t) {
                    return true
                }
            }
        }
        return false
    }
    
    private func isAppIgnored(sourceName: String?, bundleId: String?) -> Bool {
        let cleanName = (sourceName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBundle = (bundleId ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 0. Ignore self (LibrePaste should never capture its own internal clips)
        if cleanBundle == (Bundle.main.bundleIdentifier ?? "").lowercased() {
            return true
        }
        
        // 1. Password manager check
        let ignorePasswords = DatabaseManager.shared.getSetting("ignorePasswords")
        if ignorePasswords == nil || ignorePasswords == "true" {
            if passwordManagerNames.contains(cleanName) || passwordManagerNames.contains(cleanBundle) {
                return true
            }
            for pm in passwordManagerNames {
                if cleanName.contains(pm) || cleanBundle.contains(pm) {
                    return true
                }
            }
        }
        
        // 2. Custom ignored apps from settings
        if let ignoredSetting = DatabaseManager.shared.getSetting("ignoredApps"),
           let data = ignoredSetting.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in json {
                let name = (item["name"] as? String ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let path = (item["path"] as? String ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && (cleanName.contains(name) || name.contains(cleanName)) {
                    return true
                }
                if !path.isEmpty && (cleanName.contains(path) || cleanBundle.contains(path)) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func readClipboard(pasteboard: NSPasteboard, sourceName: String?, bundleId: String?) -> ClipRecord? {
        // 1. Check for Image (Extract native raw image data preserving format)
        if let (imageData, ext, size) = extractRawImageData(from: pasteboard) {
            let hash = HashHelper.sha256(imageData)
            if hash == lastHash { return nil }
            
            let fileName = "\(String(hash.prefix(16))).\(ext)"
            let fileURL = DatabaseManager.shared.imagesDir.appendingPathComponent(fileName)
            
            DispatchQueue.global(qos: .utility).async {
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    try? imageData.write(to: fileURL)
                }
                ThumbnailManager.shared.generateThumbnailInBackground(for: fileURL.path)
            }
            
            let preview = "Image \(Int(size.width)) × \(Int(size.height))"
            
            return ClipRecord(
                type: .image,
                content: "",
                rtf: nil,
                imagePath: fileURL.path,
                preview: preview,
                hash: hash,
                sourceName: sourceName,
                sourceIcon: bundleId
            )
        }
        
        // 2. Check for Text / HTML / RTF
        let text = pasteboard.string(forType: .string) ?? ""
        let html = pasteboard.string(forType: .html) ?? ""
        let rtfData = pasteboard.data(forType: .rtf)
        let rtf = rtfData.flatMap { String(data: $0, encoding: .utf8) }
        
        if text.isEmpty && html.isEmpty {
            return nil
        }
        
        // Classify
        let type: ClipType
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty && isURL(trimmedText) {
            type = .link
        } else if hasRichFormatting(html) {
            type = .richtext
        } else {
            type = .text
        }
        
        let hashSource = !html.isEmpty ? html : (!text.isEmpty ? text : (rtf ?? ""))
        let hash = HashHelper.sha256(hashSource)
        if hash == lastHash {
            return nil
        }
        
        let content = !html.isEmpty ? html : text
        let preview = buildPreview(text: !text.isEmpty ? text : stripHTML(html))
        
        return ClipRecord(
            type: type,
            content: content,
            rtf: rtf,
            imagePath: nil,
            preview: preview,
            hash: hash,
            sourceName: sourceName,
            sourceIcon: bundleId
        )
    }
    
    private func isURL(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return urlRegex?.firstMatch(in: string, options: [], range: range) != nil
    }
    
    private func hasRichFormatting(_ html: String) -> Bool {
        guard !html.isEmpty else { return false }
        let range = NSRange(location: 0, length: html.utf16.count)
        return richFormatRegex?.firstMatch(in: html, options: [], range: range) != nil
    }
    
    private func stripHTML(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
    
    private func buildPreview(text: String) -> String {
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Native Image Extraction
    
    private func extractRawImageData(from pasteboard: NSPasteboard) -> (data: Data, ext: String, size: CGSize)? {
        // 1. Check if pasteboard has a local file URL to an image (e.g. copied from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstUrl = urls.first, firstUrl.isFileURL {
            let ext = firstUrl.pathExtension.lowercased()
            if let utType = UTType(filenameExtension: ext), utType.conforms(to: .image) {
                if let fileData = try? Data(contentsOf: firstUrl), !fileData.isEmpty,
                   let img = NSImage(data: fileData), img.isValid {
                    return (fileData, ext, img.size)
                }
            }
        }

        // 2. Preferred raw image types directly from pasteboard (preserving original format)
        let formatPriority: [(type: NSPasteboard.PasteboardType, ext: String)] = [
            (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif"),
            (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg"),
            (NSPasteboard.PasteboardType("public.jpeg-2000"), "jp2"),
            (NSPasteboard.PasteboardType(UTType.webP.identifier), "webp"),
            (NSPasteboard.PasteboardType(UTType.heic.identifier), "heic"),
            (NSPasteboard.PasteboardType(UTType.png.identifier), "png"),
            (.png, "png")
        ]
        
        for item in formatPriority {
            if let data = pasteboard.data(forType: item.type), !data.isEmpty {
                if let img = NSImage(data: data), img.isValid {
                    // Smart Compression for PNG:
                    // Chrome and some web sources export uncompressed PNG for regular photos.
                    // If the PNG has no alpha channel (completely opaque), convert to JPEG 0.85
                    // to reduce size by 5x-10x while maintaining transparency for icons/stickers.
                    if item.ext == "png",
                       let tiff = img.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       !rep.hasAlpha,
                       let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
                       jpegData.count < data.count {
                        return (jpegData, "jpg", img.size)
                    }
                    return (data, item.ext, img.size)
                }
            }
        }
        
        // 3. Fallback to NSImage if only TIFF or generic pasteboard representation exists
        if let image = NSImage(pasteboard: pasteboard), image.isValid {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData) {
                if !bitmap.hasAlpha,
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                    return (jpegData, "jpg", image.size)
                } else if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    return (pngData, "png", image.size)
                }
            }
        }
        
        return nil
    }
}

