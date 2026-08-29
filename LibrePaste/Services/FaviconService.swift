//
//  FaviconService.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import AppKit
import Foundation
import SwiftUI

public final class FaviconService: @unchecked Sendable {
    public static let shared = FaviconService()
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let negativeCache = NSCache<NSString, NSDate>()
    public let diskCacheDir: URL
    
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]
    private let lock = NSLock()
    
    // Dedicated URLSession with custom User-Agent and fast timeouts
    private let session: URLSession
    
    private init() {
        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB max RAM cache
        negativeCache.countLimit = 500
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let appSupportDir = appSupport.appendingPathComponent("LibrePaste", isDirectory: true)
        diskCacheDir = appSupportDir.appendingPathComponent("favicons", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 12.0
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
        ]
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Synchronous RAM Lookup (0ms Main Thread)
    
    /// Instant RAM cache lookup
    public func cachedFavicon(for urlString: String) -> NSImage? {
        guard let host = extractHost(from: urlString) else { return nil }
        return memoryCache.object(forKey: host as NSString)
    }
    
    // MARK: - Asynchronous Load
    
    /// Loads the favicon directly from the website, with multi-level cache (RAM -> Disk -> Direct Web Fetch)
    public func loadFavicon(for urlString: String) async -> NSImage? {
        guard let (pageURL, host, rootURL) = parseAndNormalize(urlString) else {
            return nil
        }
        
        let cacheKey = host as NSString
        
        // 1. RAM Cache
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }
        
        // 2. Negative Cache (failed recently within 10 minutes)
        if let failedDate = negativeCache.object(forKey: cacheKey) {
            if Date().timeIntervalSince(failedDate as Date) < 600 {
                return nil
            }
        }
        
        // 3. Disk Cache
        let diskURL = diskCacheDir.appendingPathComponent("\(HashHelper.sha256(host)).dat")
        if FileManager.default.fileExists(atPath: diskURL.path),
           let diskData = try? Data(contentsOf: diskURL),
           let diskImage = NSImage(data: diskData),
           diskImage.isValid {
            cacheToMemory(diskImage, for: host)
            return diskImage
        }
        
        // 4. In-Flight Task Deduplication (Atomic check-and-insert under lock)
        let task: Task<NSImage?, Never> = lock.withLock {
            if let existing = inFlightTasks[host] {
                return existing
            }
            let newTask = Task<NSImage?, Never>.detached(priority: .userInitiated) { [weak self] () -> NSImage? in
                guard let self = self else { return nil }
                return await self.fetchDirectFaviconFromWeb(pageURL: pageURL, host: host, rootURL: rootURL)
            }
            inFlightTasks[host] = newTask
            return newTask
        }
        
        let result = await task.value
        
        lock.withLock {
            if inFlightTasks[host] == task {
                inFlightTasks.removeValue(forKey: host)
            }
        }
        
        if let image = result {
            cacheToMemory(image, for: host)
        } else {
            negativeCache.setObject(NSDate(), forKey: cacheKey)
        }
        
        return result
    }
    
    // MARK: - Prefetching
    
    /// Warm up favicons in the background so they are ready instantly
    public func prefetchFavicons(for urlStrings: [String]) {
        guard !urlStrings.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            for urlString in urlStrings {
                _ = await self.loadFavicon(for: urlString)
            }
        }
    }
    
    public func prefetchFavicon(for urlString: String) {
        Task.detached(priority: .utility) { [weak self] in
            _ = await self?.loadFavicon(for: urlString)
        }
    }
    
    // MARK: - Direct Web Fetching Implementation
    
    private func fetchDirectFaviconFromWeb(pageURL: URL, host: String, rootURL: URL) async -> NSImage? {
        var candidateURLs: [URL] = []
        
        // Step 1: Attempt to inspect HTML directly from the target page
        if let htmlCandidates = await extractFaviconURLsFromHTML(pageURL: pageURL, rootURL: rootURL) {
            candidateURLs.append(contentsOf: htmlCandidates)
        }
        
        // Step 2: If page is a deep path (pageURL != rootURL) and no icon tag found, try root domain HTML
        if candidateURLs.isEmpty && pageURL.path != rootURL.path && !pageURL.path.isEmpty && pageURL.path != "/" {
            if let rootCandidates = await extractFaviconURLsFromHTML(pageURL: rootURL, rootURL: rootURL) {
                candidateURLs.append(contentsOf: rootCandidates)
            }
        }
        
        // Step 3: Append well-known direct fallback endpoints on the target host
        let rootScheme = rootURL.scheme ?? "https"
        let fallbackStrings = [
            "\(rootScheme)://\(host)/apple-touch-icon.png",
            "\(rootScheme)://\(host)/apple-touch-icon-precomposed.png",
            "\(rootScheme)://\(host)/favicon.ico",
            "\(rootScheme)://\(host)/favicon.png"
        ]
        for fallbackStr in fallbackStrings {
            if let fallbackURL = URL(string: fallbackStr), !candidateURLs.contains(fallbackURL) {
                candidateURLs.append(fallbackURL)
            }
        }
        
        // Step 4: Try downloading candidates in prioritized order
        for candidateURL in candidateURLs {
            if let image = await downloadAndCacheImage(from: candidateURL, for: host) {
                return image
            }
        }
        
        return nil
    }
    
    /// Fetches the HTML head of the page directly and parses `<link rel="...icon">` tags
    private func extractFaviconURLsFromHTML(pageURL: URL, rootURL: URL) async -> [URL]? {
        do {
            var request = URLRequest(url: pageURL)
            request.httpMethod = "GET"
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...399).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let finalBaseURL = httpResponse.url ?? pageURL
            
            // Convert initial HTML chunk (first 128KB is more than enough for <head>) to string
            let prefixData = data.prefix(128 * 1024)
            let htmlString = String(data: prefixData, encoding: .utf8)
                ?? String(data: prefixData, encoding: .isoLatin1)
                ?? String(data: prefixData, encoding: .ascii)
                ?? ""
            
            guard !htmlString.isEmpty else { return nil }
            return parseIconLinksFromHTML(htmlString, baseURL: finalBaseURL, rootURL: rootURL)
        } catch {
            return nil
        }
    }
    
    /// Parses HTML tags for icon declarations with prioritization for higher resolution icons
    private func parseIconLinksFromHTML(_ html: String, baseURL: URL, rootURL: URL) -> [URL] {
        var highPriorityCandidates: [URL] = []
        var normalCandidates: [URL] = []
        
        // Match <link ...> tags
        let linkTagRegex = try? NSRegularExpression(
            pattern: "<link\\s+[^>]*>",
            options: [.caseInsensitive]
        )
        
        guard let linkRegex = linkTagRegex else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = linkRegex.matches(in: html, options: [], range: range)
        
        for match in matches {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tagContent = String(html[tagRange])
            
            // Extract 'rel' and 'href' attributes
            guard let rel = extractAttribute("rel", from: tagContent)?.lowercased(),
                  let href = extractAttribute("href", from: tagContent),
                  !href.isEmpty else {
                continue
            }
            
            // Check if rel is an icon relation
            let isAppleTouch = rel.contains("apple-touch-icon")
            let isIcon = rel.contains("icon") || rel.contains("shortcut icon") || rel.contains("mask-icon")
            
            guard isAppleTouch || isIcon else { continue }
            
            // Resolve relative URLs
            if let resolvedURL = resolveURL(href: href, baseURL: baseURL, rootURL: rootURL) {
                let sizes = extractAttribute("sizes", from: tagContent)?.lowercased() ?? ""
                
                // Prioritize Apple Touch Icons or explicit high-res sizes (e.g. 180x180, 192x192, 128x128, 64x64, 32x32)
                if isAppleTouch || sizes.contains("180") || sizes.contains("192") || sizes.contains("128") || sizes.contains("64") || sizes.contains("32") {
                    if !highPriorityCandidates.contains(resolvedURL) {
                        highPriorityCandidates.append(resolvedURL)
                    }
                } else {
                    if !normalCandidates.contains(resolvedURL) {
                        normalCandidates.append(resolvedURL)
                    }
                }
            }
        }
        
        return highPriorityCandidates + normalCandidates
    }
    
    private func extractAttribute(_ attributeName: String, from tag: String) -> String? {
        let pattern = "(?:\\b|\\A)\(attributeName)\\s*=\\s*[\"']([^\"']+)[\"']|(?:\\b|\\A)\(attributeName)\\s*=\\s*([^\\s>]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)) else {
            return nil
        }
        
        if match.numberOfRanges > 1, let range1 = Range(match.range(at: 1), in: tag) {
            return String(tag[range1])
        } else if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: tag) {
            return String(tag[range2])
        }
        return nil
    }
    
    private func resolveURL(href: String, baseURL: URL, rootURL: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("//") {
            let scheme = rootURL.scheme ?? "https"
            return URL(string: "\(scheme):\(trimmed)")
        } else if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        } else if trimmed.hasPrefix("/") {
            let rootScheme = rootURL.scheme ?? "https"
            guard let rootHost = rootURL.host else { return nil }
            return URL(string: "\(rootScheme)://\(rootHost)\(trimmed)")
        } else {
            return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        }
    }
    
    private func downloadAndCacheImage(from url: URL, for host: String) async -> NSImage? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !data.isEmpty else {
                return nil
            }
            
            guard let image = NSImage(data: data), image.isValid, image.size.width >= 8, image.size.height >= 8 else {
                return nil
            }
            
            // Save raw binary to disk directly: 0ms PNG encoding overhead, full fidelity for ICO/PNG/SVG/WebP
            saveDataToDisk(data, for: host)
            return image
        } catch {
            return nil
        }
    }
    
    // MARK: - Cache Helpers
    
    private func cacheToMemory(_ image: NSImage, for host: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: host as NSString, cost: max(1, cost))
    }
    
    private func saveDataToDisk(_ data: Data, for host: String) {
        let diskURL = diskCacheDir.appendingPathComponent("\(HashHelper.sha256(host)).dat")
        try? data.write(to: diskURL, options: .atomic)
    }
    
    // MARK: - URL Parsing Helpers
    
    private func extractHost(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatted = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return URL(string: formatted)?.host?.lowercased()
    }
    
    private func parseAndNormalize(_ urlString: String) -> (pageURL: URL, host: String, rootURL: URL)? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let formatted = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let pageURL = URL(string: formatted),
              let host = pageURL.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        
        let scheme = pageURL.scheme ?? "https"
        guard let rootURL = URL(string: "\(scheme)://\(host)") else {
            return nil
        }
        
        return (pageURL: pageURL, host: host, rootURL: rootURL)
    }
    
    public func clearCache() {
        memoryCache.removeAllObjects()
        negativeCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheDir)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }
}
