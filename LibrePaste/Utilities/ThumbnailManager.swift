//
//  ThumbnailManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

public final class ThumbnailManager: @unchecked Sendable {
    public nonisolated static let shared = ThumbnailManager()
    
    private nonisolated(unsafe) let memoryCache = NSCache<NSString, NSImage>()
    private nonisolated(unsafe) let dimensionCache = NSCache<NSString, NSValue>()
    public let diskCacheDir: URL
    public let targetPixelSize: CGFloat = 480 // Crisp 2x retina representation for ~200pt card preview
    
    private nonisolated(unsafe) var inFlightTasks: [String: Task<NSImage?, Never>] = [:]
    private let lock = NSLock()
    
    private init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max RAM cache
        dimensionCache.countLimit = 500
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let appSupportDir = appSupport.appendingPathComponent("LibrePaste", isDirectory: true)
        diskCacheDir = appSupportDir.appendingPathComponent("thumbnails", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Synchronous RAM Lookup & Injection
    
    /// Instant 0ms memory cache lookup on the Main Thread (returns nil if not yet cached in RAM)
    public nonisolated func cachedThumbnail(for path: String) -> NSImage? {
        memoryCache.object(forKey: path as NSString)
    }
    
    /// Instant 0ms dimension cache lookup
    public nonisolated func cachedDimensions(for path: String) -> CGSize? {
        dimensionCache.object(forKey: path as NSString)?.sizeValue
    }
    
    /// Explicitly cache a preloaded or captured image into memory cache
    public nonisolated func cacheThumbnail(_ image: NSImage, for path: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: path as NSString, cost: max(1, cost))
    }
    
    /// Cache dimensions for an image path
    public nonisolated func cacheDimensions(_ size: CGSize, for path: String) {
        dimensionCache.setObject(NSValue(size: size), forKey: path as NSString)
    }
    
    // MARK: - In-Flight Deduplication Locking Helpers
    
    private nonisolated func getInFlightTask(for path: String) -> Task<NSImage?, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return inFlightTasks[path]
    }
    
    private nonisolated func setInFlightTask(_ task: Task<NSImage?, Never>, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks[path] = task
    }
    
    private nonisolated func removeInFlightTask(for path: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks.removeValue(forKey: path)
    }
    
    // MARK: - Asynchronous Loading
    
    /// Loads thumbnail asynchronously from RAM, disk cache, or by ImageIO downsampling without blocking Main Thread
    public nonisolated func loadThumbnail(for path: String) async -> NSImage? {
        // 1. Check RAM Cache
        if let cached = memoryCache.object(forKey: path as NSString) {
            return cached
        }
        
        // 2. Deduplicate in-flight task for this path
        if let existing = getInFlightTask(for: path) {
            return await existing.value
        }
        
        let task = Task<NSImage?, Never>.detached(priority: .userInitiated) { [weak self] () -> NSImage? in
            guard let self = self else { return nil }
            return self.loadOrGenerate(for: path)
        }
        setInFlightTask(task, for: path)
        
        let result = await task.value
        removeInFlightTask(for: path)
        
        return result
    }
    
    // MARK: - Prefetching
    
    /// Pre-warms thumbnails in the background so scrolling is 100% instant
    public nonisolated func prefetchThumbnails(for paths: [String]) {
        guard !paths.isEmpty else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            for path in paths.prefix(30) {
                if self.memoryCache.object(forKey: path as NSString) == nil {
                    _ = self.loadOrGenerate(for: path)
                }
            }
        }
    }
    
    /// Pre-generates thumbnail when a new clip is captured
    public nonisolated func generateThumbnailInBackground(for path: String) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            _ = self.loadOrGenerate(for: path)
        }
    }
    
    // MARK: - Internal Load / Generation Logic
    
    private nonisolated func loadOrGenerate(for path: String) -> NSImage? {
        let key = path as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        
        // 1. Check disk thumbnail cache
        if let diskThumbURL = existingDiskThumbnailURL(for: path) {
            if let image = loadCachedDiskThumbnail(from: diskThumbURL) {
                let cost = Int(image.size.width * image.size.height * 4)
                memoryCache.setObject(image, forKey: key, cost: max(1, cost))
                return image
            } else {
                // Remove corrupted disk thumbnail
                try? FileManager.default.removeItem(at: diskThumbURL)
            }
        }
        
        // 2. Verify original image file exists
        let originalURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        
        // 3. ImageIO downsampling (Never decodes full 50MB bitmap into RAM!)
        if let (nsImage, cgImage, hasAlpha) = downsampleWithImageIO(from: originalURL) {
            // Cache in memory
            let cost = cgImage.width * cgImage.height * 4
            memoryCache.setObject(nsImage, forKey: key, cost: cost)
            
            // Save thumbnail to disk cache for future launches
            let targetDiskURL = diskThumbnailURL(for: path, hasAlpha: hasAlpha)
            saveThumbnailToDisk(cgImage: cgImage, hasAlpha: hasAlpha, destinationURL: targetDiskURL)
            
            return nsImage
        }
        
        // 4. Fallback to full NSImage decoding if ImageIO thumbnailing fails
        if let fullImage = loadFullImage(from: path) {
            let cost = Int(fullImage.size.width * fullImage.size.height * 4)
            memoryCache.setObject(fullImage, forKey: key, cost: max(1, cost))
            return fullImage
        }
        
        return nil
    }
    
    // MARK: - ImageIO Downsampling
    
    private nonisolated func downsampleWithImageIO(from url: URL) -> (image: NSImage, cgImage: CGImage, hasAlpha: Bool)? {
        guard let fileData = try? Data(contentsOf: url),
              let rawData = CryptoService.shared.decrypt(data: fileData) else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(rawData as CFData, options as CFDictionary) else {
            return nil
        }
        
        let maxPixelSize = Int(targetPixelSize)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let thumbnailCG = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        
        // Cache original image dimensions directly during ImageIO parsing to avoid secondary disk I/O
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            cacheDimensions(CGSize(width: width, height: height), for: url.path)
        }
        
        let alphaInfo = thumbnailCG.alphaInfo
        let hasAlpha = (alphaInfo == .first || alphaInfo == .last ||
                        alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast)
        
        let size = NSSize(width: thumbnailCG.width, height: thumbnailCG.height)
        let nsImage = NSImage(cgImage: thumbnailCG, size: size)
        
        return (nsImage, thumbnailCG, hasAlpha)
    }
    
    private nonisolated func loadCachedDiskThumbnail(from url: URL) -> NSImage? {
        guard let fileData = try? Data(contentsOf: url),
              let rawData = CryptoService.shared.decrypt(data: fileData) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(rawData as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
    
    private nonisolated func saveThumbnailToDisk(cgImage: CGImage, hasAlpha: Bool, destinationURL: URL) {
        let uti: CFString = hasAlpha ? UTType.png.identifier as CFString : UTType.jpeg.identifier as CFString
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, uti, 1, nil) else {
            return
        }
        
        var properties: [CFString: Any] = [:]
        if !hasAlpha {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.85
        }
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            let finalData = data as Data
            if let encrypted = CryptoService.shared.encrypt(data: finalData) {
                try? encrypted.write(to: destinationURL)
            }
        }
    }
    
    // MARK: - Decrypted Full Image Access & Dimension Metadata
    
    /// Returns image dimensions (width, height) synchronously if cached, otherwise nil
    public nonisolated func imageDimensions(for path: String) -> CGSize? {
        if let cached = cachedDimensions(for: path) {
            return cached
        }
        return nil
    }
    
    /// Loads pixel dimensions of the image without decoding full bitmap into RAM
    public nonisolated func loadImageDimensions(for path: String) async -> CGSize? {
        if let cached = cachedDimensions(for: path) {
            return cached
        }
        
        return await Task.detached(priority: .utility) { [weak self] () -> CGSize? in
            guard let self = self else { return nil }
            guard let rawData = self.loadDecryptedImageData(from: path) else { return nil }
            
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false
            ]
            guard let imageSource = CGImageSourceCreateWithData(rawData as CFData, options as CFDictionary) else {
                return nil
            }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
                return nil
            }
            let size = CGSize(width: width, height: height)
            self.cacheDimensions(size, for: path)
            return size
        }.value
    }
    
    /// Loads the full-size decrypted image from disk (for QuickLook Preview)
    public nonisolated func loadFullImage(from path: String) -> NSImage? {
        guard let data = loadDecryptedImageData(from: path) else { return nil }
        return NSImage(data: data)
    }
    
    /// Loads the decrypted raw image data from disk (for Pasteboard / Drag & Drop)
    public nonisolated func loadDecryptedImageData(from path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        guard let fileData = try? Data(contentsOf: url) else { return nil }
        return CryptoService.shared.decrypt(data: fileData)
    }
    
    // MARK: - Disk Path Utilities
    
    private nonisolated func diskThumbnailURL(for originalPath: String, hasAlpha: Bool) -> URL {
        let originalURL = URL(fileURLWithPath: originalPath)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let ext = hasAlpha ? "png" : "jpg"
        return diskCacheDir.appendingPathComponent("\(baseName).thumb.\(ext)")
    }
    
    private nonisolated func existingDiskThumbnailURL(for originalPath: String) -> URL? {
        let originalURL = URL(fileURLWithPath: originalPath)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        
        let jpgURL = diskCacheDir.appendingPathComponent("\(baseName).thumb.jpg")
        if FileManager.default.fileExists(atPath: jpgURL.path) {
            return jpgURL
        }
        
        let pngURL = diskCacheDir.appendingPathComponent("\(baseName).thumb.png")
        if FileManager.default.fileExists(atPath: pngURL.path) {
            return pngURL
        }
        
        return nil
    }
    
    // MARK: - Cleanup Helpers
    
    public nonisolated static var dragTempDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LibrePasteDrag", isDirectory: true)
    }
    
    public nonisolated static var previewTempDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LibrePastePreview", isDirectory: true)
    }
    
    /// Deletes all decrypted temp files corresponding to an image file (e.g. from drag & drop or Preview.app)
    public nonisolated func deleteDecryptedTempFiles(for originalPath: String) {
        let originalURL = URL(fileURLWithPath: originalPath)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let fm = FileManager.default
        
        let dirs = [Self.dragTempDir, Self.previewTempDir]
        for dir in dirs {
            if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
                for file in files where file.hasPrefix(baseName) {
                    let fullPath = dir.appendingPathComponent(file).path
                    try? fm.removeItem(atPath: fullPath)
                }
            }
        }
    }
    
    /// Completely clears all decrypted temp files in temporary directory
    public nonisolated func clearAllDecryptedTempFiles() {
        let fm = FileManager.default
        let dirs = [Self.dragTempDir, Self.previewTempDir]
        for dir in dirs {
            try? fm.removeItem(at: dir)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    public nonisolated func deleteThumbnail(for originalPath: String) {
        memoryCache.removeObject(forKey: originalPath as NSString)
        dimensionCache.removeObject(forKey: originalPath as NSString)
        
        let originalURL = URL(fileURLWithPath: originalPath)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let fm = FileManager.default
        
        let jpg = diskCacheDir.appendingPathComponent("\(baseName).thumb.jpg")
        try? fm.removeItem(at: jpg)
        let png = diskCacheDir.appendingPathComponent("\(baseName).thumb.png")
        try? fm.removeItem(at: png)
        
        deleteDecryptedTempFiles(for: originalPath)
    }
    
    public nonisolated func clearCache() {
        memoryCache.removeAllObjects()
        dimensionCache.removeAllObjects()
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: diskCacheDir.path) {
            for file in files {
                let p = diskCacheDir.appendingPathComponent(file)
                try? fm.removeItem(at: p)
            }
        }
        clearAllDecryptedTempFiles()
    }
}
