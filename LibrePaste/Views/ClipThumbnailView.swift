//
//  ClipThumbnailView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct ClipThumbnailView: View {
    public let imagePath: String?
    public let previewText: String
    public let showDimensions: Bool
    
    @State private var thumbnail: NSImage?
    @State private var dimensions: CGSize?
    
    public init(imagePath: String?, previewText: String, showDimensions: Bool = false) {
        self.imagePath = imagePath
        self.previewText = previewText
        self.showDimensions = showDimensions
        
        // Fast-path: Check RAM cache immediately on initialization to render frame 0 with 0 latency
        if let path = imagePath {
            if let cached = ThumbnailManager.shared.cachedThumbnail(for: path) {
                _thumbnail = State(initialValue: cached)
            }
            if let cachedDim = ThumbnailManager.shared.cachedDimensions(for: path) {
                _dimensions = State(initialValue: cachedDim)
            }
        }
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area
            if let img = currentImage {
                ZStack {
                    // Checkerboard pattern background for transparent PNGs (just like Paste)
                    CheckerboardPatternView(size: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            } else if let path = imagePath, !path.isEmpty {
                // Background loading placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                    
                    ProgressView()
                        .scaleEffect(0.65)
                        .opacity(0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty / missing image fallback
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text(previewText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Image Dimensions Pill Badge (Paste app signature style, e.g. "1180 × 1260")
            if showDimensions, let dim = currentDimensions, dim.width > 0, dim.height > 0, currentImage != nil {
                Text("\(Int(dim.width)) × \(Int(dim.height))")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.58))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                    .padding(.bottom, 5)
                    .transition(.opacity)
            }
        }
        .task(id: imagePath) {
            guard let path = imagePath, !path.isEmpty else {
                thumbnail = nil
                dimensions = nil
                return
            }
            
            // Check memory caches; reset if not in RAM to prevent showing stale image/dimensions
            if let cached = ThumbnailManager.shared.cachedThumbnail(for: path) {
                self.thumbnail = cached
            } else {
                self.thumbnail = nil
            }
            if let cachedDim = ThumbnailManager.shared.cachedDimensions(for: path) {
                self.dimensions = cachedDim
            } else {
                self.dimensions = nil
            }
            
            // Async load thumbnail if not in memory
            if self.thumbnail == nil {
                if let loaded = await ThumbnailManager.shared.loadThumbnail(for: path) {
                    if !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.thumbnail = loaded
                        }
                    }
                }
            }
            
            // Async load dimensions if still not available and showDimensions is requested
            if self.dimensions == nil && showDimensions {
                if let cachedDim = ThumbnailManager.shared.cachedDimensions(for: path) {
                    if !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            self.dimensions = cachedDim
                        }
                    }
                } else if let loadedDim = await ThumbnailManager.shared.loadImageDimensions(for: path) {
                    if !Task.isCancelled {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            self.dimensions = loadedDim
                        }
                    }
                }
            }
        }
    }
    
    private var currentImage: NSImage? {
        if let path = imagePath, let cached = ThumbnailManager.shared.cachedThumbnail(for: path) {
            return cached
        }
        return thumbnail
    }
    
    private var currentDimensions: CGSize? {
        if let path = imagePath, let cached = ThumbnailManager.shared.cachedDimensions(for: path) {
            return cached
        }
        return dimensions
    }
}
