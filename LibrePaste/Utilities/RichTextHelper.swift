//
//  RichTextHelper.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import AppKit

public final class RichTextHelper {
    public static func parse(content: String, rtf: String?, isDark: Bool) -> NSAttributedString? {
        // 1. Try RTF
        if let rtf = rtf, let data = rtf.data(using: .utf8) {
            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                return adaptForDisplay(attr, isDark: isDark)
            }
        }
        if content.hasPrefix("{\\rtf"), let data = content.data(using: .utf8) {
            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                return adaptForDisplay(attr, isDark: isDark)
            }
        }
        
        // 2. Try HTML
        if content.contains("<") && content.contains(">") {
            let sanitized = sanitizeHTML(content)
            if let data = sanitized.data(using: .utf8),
               let attr = try? NSAttributedString(
                   data: data,
                   options: [
                       .documentType: NSAttributedString.DocumentType.html,
                       .characterEncoding: String.Encoding.utf8.rawValue
                   ],
                   documentAttributes: nil
               ) {
                return adaptForDisplay(attr, isDark: isDark)
            }
        }
        
        return nil
    }
    
    /// Preprocess HTML to fix WebKit layout quirks with modern web formats (Facebook, Twitter, Google Docs, etc.)
    public static func sanitizeHTML(_ html: String) -> String {
        var result = html
        
        // 1. Replace web emoji image tags (<img ... alt="⚜️" ...>) with native emoji Unicode
        if let regex = try? NSRegularExpression(pattern: "<img[^>]*alt=[\"']([^\"']+)[\"'][^>]*>", options: [.caseInsensitive]) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let altRange = match.range(at: 1)
                let altText = nsString.substring(with: altRange)
                let isEmojiOrSymbol = altText.unicodeScalars.contains { $0.properties.isEmoji }
                if isEmojiOrSymbol && altText.count <= 4 {
                    result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: altText)
                }
            }
        }
        
        // 2. Normalize flex / inline-flex in CSS style attributes
        result = result.replacingOccurrences(
            of: "display\\s*:\\s*inline-flex",
            with: "display: inline",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "display\\s*:\\s*flex",
            with: "display: inline",
            options: .regularExpression
        )
        
        // 3. Normalize white-space in styles to prevent empty bullet paragraphs from Google Docs / web editors
        result = result.replacingOccurrences(
            of: "white-space\\s*:\\s*(pre-wrap|pre|break-spaces)",
            with: "white-space: normal",
            options: .regularExpression
        )
        
        // 4. Remove redundant bullet characters or bullet spans directly at the beginning of <li>
        // Matches: <li>• Item, <li>&bull; Item, <li><span>•</span> Item, <li><span class="bullet">•</span> Item
        if let bulletRegex = try? NSRegularExpression(
            pattern: "(<li[^>]*>\\s*(?:<(?:span|p|div)[^>]*>)?\\s*)(?:[•◦▪⁃\\u2022\\u25E6\\u25AA\\u2043]|&bull;|&#8226;|&#x2022;)\\s*(?:<\\/(?:span|p|div)>)?\\s*",
            options: [.caseInsensitive]
        ) {
            let nsString = result as NSString
            result = bulletRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: nsString.length),
                withTemplate: "$1"
            )
        }
        
        return result
    }
    
    public static func adaptForDisplay(_ attr: NSAttributedString, isDark: Bool) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attr)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return attr }
        
        // 1. Fix duplicate list markers in TextKit 2 (macOS 12+)
        // When WebKit converts HTML to NSAttributedString, it embeds list markers (\t•\t, \t1\t, etc.)
        // directly into the text characters, while ALSO populating NSParagraphStyle.textLists.
        // In TextKit 2, NSTextLayoutManager automatically adds an NSTextListElement marker
        // whenever textLists is non-empty, causing list bullets/numbers to appear duplicated (e.g. • • or 1. 1.).
        // If a paragraph already contains embedded list marker tabs/prefixes, we clear textLists.
        sanitizeListStyles(in: mutable)
        
        // 2. Adapt text color for current appearance (Dark/Light mode)
        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? NSColor {
                let srgb = color.usingColorSpace(.sRGB) ?? color
                let lum = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
                if isDark && lum < 0.4 {
                    mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                } else if !isDark && lum > 0.85 {
                    mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                }
            } else {
                mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }
        }
        
        // 3. Ensure minimum font size for readability
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                if font.pointSize < 13 {
                    let descriptor = font.fontDescriptor
                    let newFont = NSFont(descriptor: descriptor, size: 13.5) ?? font
                    mutable.addAttribute(.font, value: newFont, range: range)
                }
            } else {
                mutable.addAttribute(.font, value: NSFont.systemFont(ofSize: 13.5), range: range)
            }
        }
        
        return mutable
    }
    
    /// Normalizes paragraph styles so that embedded list markers (\t•\t, \t1\t) from WebKit HTML import
    /// do not conflict with TextKit 2's automatic NSTextList markers.
    private static func sanitizeListStyles(in mutable: NSMutableAttributedString) {
        let nsString = mutable.string as NSString
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return }
        
        nsString.enumerateSubstrings(in: fullRange, options: [.byParagraphs]) { _, subRange, enclosingRange, _ in
            guard subRange.length > 0 else { return }
            let pText = nsString.substring(with: subRange)
            let trimmed = pText.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\t") || pText.hasPrefix("\t") {
                mutable.enumerateAttribute(.paragraphStyle, in: enclosingRange, options: []) { val, range, _ in
                    if let style = val as? NSParagraphStyle, !style.textLists.isEmpty {
                        let newStyle = style.mutableCopy() as! NSMutableParagraphStyle
                        newStyle.textLists = []
                        mutable.addAttribute(.paragraphStyle, value: newStyle, range: range)
                    }
                }
            }
        }
    }
    
    public static func stripHTML(_ html: String) -> String {
        guard html.contains("<") && html.contains(">") else {
            return html
        }
        return html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</(p|div|tr|li|h[1-6])>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
