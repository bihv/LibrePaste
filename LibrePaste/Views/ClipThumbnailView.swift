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
    
    @State private var thumbnail: NSImage?
    
    public init(imagePath: String?, previewText: String) {
        self.imagePath = imagePath
        self.previewText = previewText
        
        // Fast-path: Check RAM cache immediately on initialization to render frame 0 with 0 latency
        if let path = imagePath, let cached = ThumbnailManager.shared.cachedThumbnail(for: path) {
            _thumbnail = State(initialValue: cached)
        }
    }
    
    public var body: some View {
        Group {
            if let img = currentImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            } else if let path = imagePath, !path.isEmpty {
                // Background loading placeholder (Subtle, no layout jump)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        }
        .task(id: imagePath) {
            guard let path = imagePath, !path.isEmpty else { return }
            // If already cached in state or RAM, skip background work
            if thumbnail != nil { return }
            if let cached = ThumbnailManager.shared.cachedThumbnail(for: path) {
                self.thumbnail = cached
                return
            }
            
            // Asynchronously load/downsample on background queue
            if let loaded = await ThumbnailManager.shared.loadThumbnail(for: path) {
                if !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.thumbnail = loaded
                    }
                }
            }
        }
    }
    
    private var currentImage: NSImage? {
        if let thumb = thumbnail {
            return thumb
        }
        if let path = imagePath {
            return ThumbnailManager.shared.cachedThumbnail(for: path)
        }
        return nil
    }
}
