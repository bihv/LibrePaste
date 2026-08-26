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
    
    /// Preprocess HTML to fix WebKit layout quirks with modern web formats (Facebook, Twitter, etc.)
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
        
        return result
    }
    
    public static func adaptForDisplay(_ attr: NSAttributedString, isDark: Bool) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attr)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return attr }
        
        // Adapt text color for current appearance (Dark/Light mode)
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
        
        // Ensure minimum font size for readability
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
}
