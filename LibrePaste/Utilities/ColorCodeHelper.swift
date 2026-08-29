//
//  ColorCodeHelper.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public enum ColorFormat: String, Sendable, CaseIterable {
    case hex = "HEX"
    case rgb = "RGB"
    case hsl = "HSL"
    case swift = "Swift"
    case named = "Named"
}

public struct DetectedColorInfo: Equatable, Hashable, Sendable {
    public let rawText: String
    public let format: ColorFormat
    public let red: Double   // 0.0 ... 1.0
    public let green: Double // 0.0 ... 1.0
    public let blue: Double  // 0.0 ... 1.0
    public let alpha: Double // 0.0 ... 1.0
    
    public init(
        rawText: String,
        format: ColorFormat,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0
    ) {
        self.rawText = rawText
        self.format = format
        self.red = max(0.0, min(1.0, red))
        self.green = max(0.0, min(1.0, green))
        self.blue = max(0.0, min(1.0, blue))
        self.alpha = max(0.0, min(1.0, alpha))
    }
    
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
    
    public var r255: Int { Int((red * 255.0).rounded()) }
    public var g255: Int { Int((green * 255.0).rounded()) }
    public var b255: Int { Int((blue * 255.0).rounded()) }
    public var aPercent: Int { Int((alpha * 100.0).rounded()) }
    
    public var hex6String: String {
        String(format: "#%02X%02X%02X", r255, g255, b255)
    }
    
    public var hex8String: String {
        let a255 = Int((alpha * 255.0).rounded())
        return String(format: "#%02X%02X%02X%02X", r255, g255, b255, a255)
    }
    
    public var hexString: String {
        if alpha < 0.999 {
            return hex8String
        }
        return hex6String
    }
    
    public var rgbString: String {
        if alpha < 0.999 {
            let formattedAlpha = alpha == Double(Int(alpha)) ? String(format: "%.1f", alpha) : String(format: "%.2f", alpha)
            return "rgba(\(r255), \(g255), \(b255), \(formattedAlpha))"
        }
        return "rgb(\(r255), \(g255), \(b255))"
    }
    
    public var hslValues: (h: Int, s: Int, l: Int) {
        let maxVal = max(red, max(green, blue))
        let minVal = min(red, min(green, blue))
        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2.0
        
        if maxVal != minVal {
            let d = maxVal - minVal
            s = l > 0.5 ? d / (2.0 - maxVal - minVal) : d / (maxVal + minVal)
            if maxVal == red {
                h = (green - blue) / d + (green < blue ? 6.0 : 0.0)
            } else if maxVal == green {
                h = (blue - red) / d + 2.0
            } else {
                h = (red - green) / d + 4.0
            }
            h /= 6.0
        }
        return (Int((h * 360.0).rounded()), Int((s * 100.0).rounded()), Int((l * 100.0).rounded()))
    }
    
    public var hslString: String {
        let (h, s, l) = hslValues
        if alpha < 0.999 {
            let formattedAlpha = alpha == Double(Int(alpha)) ? String(format: "%.1f", alpha) : String(format: "%.2f", alpha)
            return "hsla(\(h), \(s)%, \(l)%, \(formattedAlpha))"
        }
        return "hsl(\(h), \(s)%, \(l)%)"
    }
    
    public var swiftCodeString: String {
        if alpha < 0.999 {
            return String(format: "Color(red: %.3f, green: %.3f, blue: %.3f, opacity: %.2f)", red, green, blue, alpha)
        }
        return String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", red, green, blue)
    }
    
    public var nsColorCodeString: String {
        return String(format: "NSColor(srgbRed: %.3f, green: %.3f, blue: %.3f, alpha: %.2f)", red, green, blue, alpha)
    }
    
    /// Relative Luminance (WCAG 2.0 standards)
    public var luminance: Double {
        func adjust(_ channel: Double) -> Double {
            if channel <= 0.03928 {
                return channel / 12.92
            } else {
                return pow((channel + 0.055) / 1.055, 2.4)
            }
        }
        return 0.2126 * adjust(red) + 0.7152 * adjust(green) + 0.0722 * adjust(blue)
    }
    
    public var isDark: Bool {
        luminance < 0.45
    }
    
    public var contrastTextColor: Color {
        isDark ? .white : Color(red: 0.1, green: 0.1, blue: 0.12)
    }
    
    public var subtleBorderColor: Color {
        isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }
}

private final class ColorCacheBox {
    let info: DetectedColorInfo?
    init(_ info: DetectedColorInfo?) {
        self.info = info
    }
}

public final class ColorCodeHelper: @unchecked Sendable {
    public static let shared = ColorCodeHelper()
    
    private let cache = NSCache<NSString, ColorCacheBox>()
    
    private init() {
        cache.countLimit = 500
    }
    
    // MARK: - Public API
    
    /// Analyzes a string to determine if it strictly or predominantly represents a color code.
    public func detectColor(in text: String) -> DetectedColorInfo? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        guard !trimmed.isEmpty, trimmed.count <= 120 else { return nil }
        
        let cacheKey = trimmed as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached.info
        }
        
        let result = parseColor(from: trimmed)
        cache.setObject(ColorCacheBox(result), forKey: cacheKey)
        return result
    }
    
    // MARK: - Parsing Engine
    
    private func parseColor(from text: String) -> DetectedColorInfo? {
        // 1. Try Hex Color (#RGB, #RGBA, #RRGGBB, #RRGGBBAA, 0x...)
        if let hex = parseHexColor(text) {
            return hex
        }
        
        // 2. Try CSS RGB / RGBA
        if let rgb = parseRgbColor(text) {
            return rgb
        }
        
        // 3. Try CSS HSL / HSLA
        if let hsl = parseHslColor(text) {
            return hsl
        }
        
        // 4. Try Swift / AppKit Code Formats
        if let swiftColor = parseSwiftCodeColor(text) {
            return swiftColor
        }
        
        // 5. Try Named Web Colors
        if let named = parseNamedColor(text) {
            return named
        }
        
        return nil
    }
    
    // MARK: - Hex Parser
    
    private func parseHexColor(_ text: String) -> DetectedColorInfo? {
        var clean = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        
        let hasHashPrefix = clean.hasPrefix("#")
        let has0xPrefix = clean.lowercased().hasPrefix("0x")
        
        if hasHashPrefix {
            clean = String(clean.dropFirst())
        } else if has0xPrefix {
            clean = String(clean.dropFirst(2))
        } else {
            // For bare hex without prefix: only accept if strictly 6 or 8 hex characters
            // AND contains at least one hex letter (A-F/a-f) to prevent false positives on numeric OTPs, dates, and IDs.
            let hexLetters = CharacterSet(charactersIn: "ABCDEFabcdef")
            let validHexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
            if (clean.count == 6 || clean.count == 8) &&
                clean.unicodeScalars.allSatisfy({ validHexChars.contains($0) }) &&
                clean.unicodeScalars.contains(where: { hexLetters.contains($0) }) {
                // Allowed bare hex with at least 1 hex letter
            } else {
                return nil
            }
        }
        
        let validHexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard !clean.isEmpty && clean.unicodeScalars.allSatisfy({ validHexChars.contains($0) }) else {
            return nil
        }
        
        var hexValue: UInt64 = 0
        guard Scanner(string: clean).scanHexInt64(&hexValue) else { return nil }
        
        let r, g, b, a: Double
        
        switch clean.count {
        case 3: // #RGB -> #RRGGBB
            let rInt = (hexValue >> 8) & 0xF
            let gInt = (hexValue >> 4) & 0xF
            let bInt = hexValue & 0xF
            r = Double(rInt * 17) / 255.0
            g = Double(gInt * 17) / 255.0
            b = Double(bInt * 17) / 255.0
            a = 1.0
            
        case 4: // #RGBA -> #RRGGBBAA
            let rInt = (hexValue >> 12) & 0xF
            let gInt = (hexValue >> 8) & 0xF
            let bInt = (hexValue >> 4) & 0xF
            let aInt = hexValue & 0xF
            r = Double(rInt * 17) / 255.0
            g = Double(gInt * 17) / 255.0
            b = Double(bInt * 17) / 255.0
            a = Double(aInt * 17) / 255.0
            
        case 6: // #RRGGBB
            r = Double((hexValue >> 16) & 0xFF) / 255.0
            g = Double((hexValue >> 8) & 0xFF) / 255.0
            b = Double(hexValue & 0xFF) / 255.0
            a = 1.0
            
        case 8: // #RRGGBBAA
            r = Double((hexValue >> 24) & 0xFF) / 255.0
            g = Double((hexValue >> 16) & 0xFF) / 255.0
            b = Double((hexValue >> 8) & 0xFF) / 255.0
            a = Double(hexValue & 0xFF) / 255.0
            
        default:
            return nil
        }
        
        return DetectedColorInfo(
            rawText: text,
            format: .hex,
            red: r,
            green: g,
            blue: b,
            alpha: a
        )
    }
    
    // MARK: - RGB / RGBA Parser
    
    private func parseRgbColor(_ text: String) -> DetectedColorInfo? {
        let lower = text.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        guard lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") else { return nil }
        guard lower.hasSuffix(")") else { return nil }
        
        let startIdx = lower.firstIndex(of: "(").map { lower.index(after: $0) } ?? lower.startIndex
        let endIdx = lower.index(before: lower.endIndex)
        let inner = String(lower[startIdx..<endIdx])
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        
        let components = inner.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard components.count == 3 || components.count == 4 else { return nil }
        
        func parseChannel(_ str: String, isAlpha: Bool = false) -> Double? {
            let s = str.trimmingCharacters(in: .whitespaces)
            if s.hasSuffix("%") {
                let numStr = s.dropLast().trimmingCharacters(in: .whitespaces)
                guard let val = Double(numStr) else { return nil }
                return val / 100.0
            }
            guard let val = Double(s) else { return nil }
            if isAlpha {
                return max(0.0, min(1.0, val))
            } else {
                return max(0.0, min(1.0, val / 255.0))
            }
        }
        
        guard let r = parseChannel(components[0]),
              let g = parseChannel(components[1]),
              let b = parseChannel(components[2]) else {
            return nil
        }
        
        var a = 1.0
        if components.count == 4 {
            guard let parsedAlpha = parseChannel(components[3], isAlpha: true) else { return nil }
            a = parsedAlpha
        }
        
        return DetectedColorInfo(
            rawText: text,
            format: .rgb,
            red: r,
            green: g,
            blue: b,
            alpha: a
        )
    }
    
    // MARK: - HSL / HSLA Parser
    
    private func parseHslColor(_ text: String) -> DetectedColorInfo? {
        let lower = text.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        guard lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(") else { return nil }
        guard lower.hasSuffix(")") else { return nil }
        
        let startIdx = lower.firstIndex(of: "(").map { lower.index(after: $0) } ?? lower.startIndex
        let endIdx = lower.index(before: lower.endIndex)
        let inner = String(lower[startIdx..<endIdx])
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "deg", with: "")
            .replacingOccurrences(of: "\t", with: " ")
        
        let components = inner.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard components.count == 3 || components.count == 4 else { return nil }
        
        guard let hVal = Double(components[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        
        func parsePercent(_ str: String) -> Double? {
            let s = str.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
            guard let val = Double(s) else { return nil }
            return max(0.0, min(1.0, val / 100.0))
        }
        
        guard let s = parsePercent(components[1]),
              let l = parsePercent(components[2]) else {
            return nil
        }
        
        var a = 1.0
        if components.count == 4 {
            let aStr = components[3].trimmingCharacters(in: .whitespaces)
            if aStr.hasSuffix("%") {
                if let aVal = parsePercent(aStr) { a = aVal }
            } else if let aVal = Double(aStr) {
                a = max(0.0, min(1.0, aVal))
            }
        }
        
        let (r, g, b) = hslToRgb(h: hVal, s: s, l: l)
        
        return DetectedColorInfo(
            rawText: text,
            format: .hsl,
            red: r,
            green: g,
            blue: b,
            alpha: a
        )
    }
    
    // MARK: - Swift / AppKit Code Parser
    
    private static let colorHexInitRegex = try? NSRegularExpression(
        pattern: #"Color\(hex:\s*["']([^"']+)["']\)"#,
        options: .caseInsensitive
    )
    
    private static let redExtractionRegex = try? NSRegularExpression(
        pattern: #"(?:red|srgbred):\s*([0-9]*\.?[0-9]+)"#,
        options: .caseInsensitive
    )
    
    private static let greenExtractionRegex = try? NSRegularExpression(
        pattern: #"green:\s*([0-9]*\.?[0-9]+)"#,
        options: .caseInsensitive
    )
    
    private static let blueExtractionRegex = try? NSRegularExpression(
        pattern: #"blue:\s*([0-9]*\.?[0-9]+)"#,
        options: .caseInsensitive
    )
    
    private static let alphaExtractionRegex = try? NSRegularExpression(
        pattern: #"(?:opacity|alpha):\s*([0-9]*\.?[0-9]+)"#,
        options: .caseInsensitive
    )
    
    private func parseSwiftCodeColor(_ text: String) -> DetectedColorInfo? {
        let lower = text.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        
        // Match Color(hex: "#...") or Color(hex: "...")
        if lower.hasPrefix("color(hex:") {
            if let regex = Self.colorHexInitRegex,
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let hexStr = String(text[range])
                if let hexResult = parseHexColor(hexStr) {
                    return DetectedColorInfo(
                        rawText: text,
                        format: .swift,
                        red: hexResult.red,
                        green: hexResult.green,
                        blue: hexResult.blue,
                        alpha: hexResult.alpha
                    )
                }
            }
        }
        
        // Match Color(red:..., green:..., blue:...) / NSColor / UIColor
        let isSwiftUI = lower.hasPrefix("color(red:") || lower.hasPrefix("color(.srgb, red:")
        let isNSColor = lower.hasPrefix("nscolor(red:") || lower.hasPrefix("nscolor(srgbred:")
        let isUIColor = lower.hasPrefix("uicolor(red:")
        
        guard isSwiftUI || isNSColor || isUIColor else { return nil }
        
        func extract(with regex: NSRegularExpression?, in str: String) -> Double? {
            guard let regex = regex,
                  let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
                  let range = Range(match.range(at: 1), in: str) else {
                return nil
            }
            return Double(String(str[range]))
        }
        
        guard let r = extract(with: Self.redExtractionRegex, in: text),
              let g = extract(with: Self.greenExtractionRegex, in: text),
              let b = extract(with: Self.blueExtractionRegex, in: text) else {
            return nil
        }
        
        let a = extract(with: Self.alphaExtractionRegex, in: text) ?? 1.0
        
        return DetectedColorInfo(
            rawText: text,
            format: .swift,
            red: r,
            green: g,
            blue: b,
            alpha: a
        )
    }
    
    // MARK: - Named Web Colors
    
    private let namedColorsMap: [String: (r: Double, g: Double, b: Double)] = [
        "black": (0.0, 0.0, 0.0),
        "white": (1.0, 1.0, 1.0),
        "red": (1.0, 0.0, 0.0),
        "green": (0.0, 0.502, 0.0),
        "blue": (0.0, 0.0, 1.0),
        "yellow": (1.0, 1.0, 0.0),
        "cyan": (0.0, 1.0, 1.0),
        "magenta": (1.0, 0.0, 1.0),
        "orange": (1.0, 0.647, 0.0),
        "purple": (0.502, 0.0, 0.502),
        "pink": (1.0, 0.753, 0.796),
        "teal": (0.0, 0.502, 0.502),
        "indigo": (0.294, 0.0, 0.510),
        "violet": (0.933, 0.510, 0.933),
        "coral": (1.0, 0.498, 0.314),
        "crimson": (0.863, 0.078, 0.235),
        "gold": (1.0, 0.843, 0.0),
        "navy": (0.0, 0.0, 0.502),
        "lime": (0.0, 1.0, 0.0),
        "turquoise": (0.251, 0.878, 0.816),
        "salmon": (0.980, 0.502, 0.447),
        "maroon": (0.502, 0.0, 0.0),
        "olive": (0.502, 0.502, 0.0),
        "aqua": (0.0, 1.0, 1.0),
        "fuchsia": (1.0, 0.0, 1.0),
        "silver": (0.753, 0.753, 0.753),
        "gray": (0.502, 0.502, 0.502),
        "grey": (0.502, 0.502, 0.502)
    ]
    
    private func parseNamedColor(_ text: String) -> DetectedColorInfo? {
        let clean = text.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        guard let rgb = namedColorsMap[clean] else { return nil }
        
        return DetectedColorInfo(
            rawText: text,
            format: .named,
            red: rgb.r,
            green: rgb.g,
            blue: rgb.b,
            alpha: 1.0
        )
    }
    
    // MARK: - Color Conversion Helpers
    
    private func hslToRgb(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        let normalizedH = ((h.truncatingRemainder(dividingBy: 360.0)) + 360.0).truncatingRemainder(dividingBy: 360.0) / 360.0
        
        func hue2rgb(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var val = t
            if val < 0 { val += 1 }
            if val > 1 { val -= 1 }
            if val < 1.0 / 6.0 { return p + (q - p) * 6.0 * val }
            if val < 1.0 / 2.0 { return q }
            if val < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - val) * 6.0 }
            return p
        }
        
        if s == 0 {
            return (r: l, g: l, b: l)
        } else {
            let q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
            let p = 2.0 * l - q
            let r = hue2rgb(p, q, normalizedH + 1.0 / 3.0)
            let g = hue2rgb(p, q, normalizedH)
            let b = hue2rgb(p, q, normalizedH - 1.0 / 3.0)
            return (r: r, g: g, b: b)
        }
    }
}

// MARK: - Checkerboard Pattern View for Alpha Preview

public struct CheckerboardPatternView: View {
    public let size: CGFloat
    
    public init(size: CGFloat = 8) {
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let cols = Int(ceil(canvasSize.width / size))
            let rows = Int(ceil(canvasSize.height / size))
            
            let lightTile = Color.primary.opacity(0.06)
            let darkTile = Color.primary.opacity(0.14)
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let isEven = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size)
                    context.fill(Path(rect), with: .color(isEven ? lightTile : darkTile))
                }
            }
        }
    }
}
