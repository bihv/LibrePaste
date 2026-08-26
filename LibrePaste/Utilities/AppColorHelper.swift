//
//  AppColorHelper.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct CardHeaderTheme: Equatable {
    public let primaryColor: Color
    public let secondaryColor: Color
    public let textColor: Color
    public let textSubColor: Color
    public let shortcutBg: Color
    public let shortcutBorder: Color
    public let isLight: Bool
    
    public init(
        primaryColor: Color,
        secondaryColor: Color,
        textColor: Color = .white,
        textSubColor: Color = Color.white.opacity(0.82),
        shortcutBg: Color = Color.black.opacity(0.24),
        shortcutBorder: Color = Color.white.opacity(0.22),
        isLight: Bool = false
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.textColor = textColor
        self.textSubColor = textSubColor
        self.shortcutBg = shortcutBg
        self.shortcutBorder = shortcutBorder
        self.isLight = isLight
    }
    
    public var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryColor, secondaryColor]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private final class CardHeaderThemeBox {
    let theme: CardHeaderTheme
    init(_ theme: CardHeaderTheme) {
        self.theme = theme
    }
}

public final class AppColorHelper {
    public static let shared = AppColorHelper()
    
    private let themeCache = NSCache<NSString, CardHeaderThemeBox>()
    private let iconCache = NSCache<NSString, NSImage>()
    
    private init() {
        themeCache.countLimit = 300
        iconCache.countLimit = 150
    }
    
    // MARK: - Vibrant Fallback Palette (chỉ dùng khi không tìm thấy icon trên hệ thống)
    private let fallbackPalette: [(primary: String, secondary: String)] = [
        ("#0284C7", "#0369A1"), // Sky Blue
        ("#6366F1", "#4F46E5"), // Indigo
        ("#8B5CF6", "#7C3AED"), // Violet
        ("#EC4899", "#DB2777"), // Pink
        ("#F43F5E", "#E11D48"), // Rose
        ("#EF4444", "#DC2626"), // Red
        ("#F97316", "#EA580C"), // Orange
        ("#F59E0B", "#D97706"), // Amber
        ("#10B981", "#059669"), // Emerald
        ("#14B8A6", "#0D9488"), // Teal
        ("#06B6D4", "#0891B2"), // Cyan
        ("#3B82F6", "#2563EB"), // Blue
        ("#A855F7", "#9333EA"), // Purple
        ("#D946EF", "#C026D3"), // Fuchsia
        ("#16A34A", "#15803D"), // Green
        ("#0EA5E9", "#0284C7")  // Ocean
    ]
    
    // MARK: - Public API
    
    /// Tính toán màu header trực tiếp từ icon của ứng dụng nguồn
    public func theme(appName: String?, bundleId: String?) -> CardHeaderTheme {
        let cacheKey = "\(bundleId ?? "")|\(appName ?? "")" as NSString
        if let cached = themeCache.object(forKey: cacheKey) {
            return cached.theme
        }
        
        let icon = getAppIcon(bundleId: bundleId, appName: appName)
        
        // Trích xuất màu nổi bật trực tiếp từ điểm ảnh của icon app
        if let icon = icon, let extracted = extractVibrantDominantColor(from: icon) {
            let theme = CardHeaderTheme(primaryColor: extracted.primary, secondaryColor: extracted.secondary)
            themeCache.setObject(CardHeaderThemeBox(theme), forKey: cacheKey)
            return theme
        }
        
        // Trường hợp bất khả kháng: không tìm thấy icon của app trên máy -> băm tên app thành màu sắc nét
        let targetStr = (appName?.isEmpty == false ? (appName ?? "unknown") : (bundleId ?? "unknown"))
        let hashPair = getHashColor(targetStr)
        let theme = CardHeaderTheme(
            primaryColor: parseHex(hashPair.primary),
            secondaryColor: parseHex(hashPair.secondary)
        )
        themeCache.setObject(CardHeaderThemeBox(theme), forKey: cacheKey)
        return theme
    }
    
    public func getAppIcon(bundleId: String?, appName: String?) -> NSImage? {
        let key = "\(bundleId ?? "")|\(appName ?? "")" as NSString
        if let cached = iconCache.object(forKey: key) {
            return cached
        }
        
        // 1. Kiểm tra nếu bundleId là đường dẫn file icon / app
        if let bundleId = bundleId, !bundleId.isEmpty {
            if bundleId.hasPrefix("/") && FileManager.default.fileExists(atPath: bundleId) {
                let img = NSWorkspace.shared.icon(forFile: bundleId)
                iconCache.setObject(img, forKey: key)
                return img
            }
            
            // 2. Tra cứu URL ứng dụng theo Bundle Identifier
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let img = NSWorkspace.shared.icon(forFile: url.path)
                iconCache.setObject(img, forKey: key)
                return img
            }
            
            // 3. Tra cứu từ danh sách ứng dụng đang chạy
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let icon = runningApp.icon {
                iconCache.setObject(icon, forKey: key)
                return icon
            }
        }
        
        // 4. Tra cứu theo tên ứng dụng (appName)
        if let appName = appName, !appName.isEmpty {
            // Kiểm tra các ứng dụng đang chạy
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.localizedName?.caseInsensitiveCompare(appName) == .orderedSame
            }), let icon = runningApp.icon {
                iconCache.setObject(icon, forKey: key)
                return icon
            }
            
            // Kiểm tra các thư mục ứng dụng chuẩn trên macOS
            let commonDirs = [
                "/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                "\(NSHomeDirectory())/Applications"
            ]
            for dir in commonDirs {
                let path = "\(dir)/\(appName).app"
                if FileManager.default.fileExists(atPath: path) {
                    let img = NSWorkspace.shared.icon(forFile: path)
                    iconCache.setObject(img, forKey: key)
                    return img
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func getHashColor(_ str: String) -> (primary: String, secondary: String) {
        var hash: Int = 0
        for u in str.utf8 {
            hash = ((hash << 5) &- hash) &+ Int(u)
        }
        let index = abs(hash) % fallbackPalette.count
        return fallbackPalette[index]
    }
    
    // MARK: - Dominant Color Extraction From Icon Pixels
    
    private struct HueBin {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        var count: Int = 0
        var totalSat: Double = 0
        var totalLight: Double = 0
        var totalH: Double = 0
    }
    
    private func extractVibrantDominantColor(from image: NSImage) -> (primary: Color, secondary: Color)? {
        let size = 32
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: size * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
        
        guard let data = rep.bitmapData else { return nil }
        
        let numBins = 24
        var bins = [HueBin](repeating: HueBin(), count: numBins)
        var totalColoredPixels = 0
        var totalOpaquePixels = 0
        var sumGreyLightness: Double = 0
        
        for i in 0..<(size * size) {
            let offset = i * 4
            let a = data[offset + 3]
            if a < 64 { continue }
            
            let r = Double(data[offset]) / 255.0
            let g = Double(data[offset + 1]) / 255.0
            let b = Double(data[offset + 2]) / 255.0
            
            totalOpaquePixels += 1
            let (h, s, l) = rgbToHsl(r: r, g: g, b: b)
            
            if s >= 0.16 && l >= 0.08 && l <= 0.92 {
                let binIdx = min(numBins - 1, max(0, Int(h / (360.0 / Double(numBins)))))
                bins[binIdx].r += r
                bins[binIdx].g += g
                bins[binIdx].b += b
                bins[binIdx].totalSat += s
                bins[binIdx].totalLight += l
                bins[binIdx].totalH += h
                bins[binIdx].count += 1
                totalColoredPixels += 1
            } else {
                sumGreyLightness += l
            }
        }
        
        // Case 1: Icon có các pixel màu nổi bật (Vibrant colored pixels)
        if totalColoredPixels > 0 {
            var bestBin: HueBin? = nil
            var maxScore: Double = -1
            
            for bin in bins {
                if bin.count == 0 { continue }
                let avgSat = bin.totalSat / Double(bin.count)
                let score = Double(bin.count) * pow(avgSat, 1.4)
                if score > maxScore {
                    maxScore = score
                    bestBin = bin
                }
            }
            
            if let best = bestBin, best.count > 0 {
                let avgH = best.totalH / Double(best.count)
                let rawAvgSat = best.totalSat / Double(best.count)
                let rawAvgL = best.totalLight / Double(best.count)
                
                // Boost độ bão hòa (74% đến 96%) để màu gradient luôn tươi tắn và tràn đầy năng lượng
                let targetSat = max(0.74, min(0.96, rawAvgSat * 1.35))
                // Độ sáng tối ưu (40% đến 50%) để chữ màu trắng bên trên luôn có độ tương phản xuất sắc
                let primaryL = max(0.40, min(0.50, rawAvgL))
                let secondaryL = max(0.30, primaryL * 0.82)
                
                let (r1, g1, b1) = hslToRgb(h: avgH, s: targetSat, l: primaryL)
                let (r2, g2, b2) = hslToRgb(h: avgH, s: targetSat, l: secondaryL)
                
                return (
                    primary: Color(.sRGB, red: r1, green: g1, blue: b1, opacity: 1.0),
                    secondary: Color(.sRGB, red: r2, green: g2, blue: b2, opacity: 1.0)
                )
            }
        }
        
        // Case 2: Icon đơn sắc đen/trắng/xám (Monochrome icon)
        if totalOpaquePixels > 0 {
            let avgL = sumGreyLightness / Double(totalOpaquePixels)
            if avgL < 0.45 {
                return (primary: parseHex("#475569"), secondary: parseHex("#334155"))
            } else {
                return (primary: parseHex("#64748b"), secondary: parseHex("#475569"))
            }
        }
        
        return nil
    }
    
    private func parseHex(_ hex: String) -> Color {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 2, 132, 199)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    private func rgbToHsl(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2.0
        
        if maxVal != minVal {
            let d = maxVal - minVal
            s = l > 0.5 ? d / (2.0 - maxVal - minVal) : d / (maxVal + minVal)
            if maxVal == r {
                h = (g - b) / d + (g < b ? 6.0 : 0.0)
            } else if maxVal == g {
                h = (b - r) / d + 2.0
            } else {
                h = (r - g) / d + 4.0
            }
            h /= 6.0
        }
        return (h: h * 360.0, s: s, l: l)
    }
    
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
