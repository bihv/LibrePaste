//
//  FaviconImageView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct FaviconImageView: View {
    public let urlString: String
    public let size: CGFloat
    public let fallbackSystemImage: String
    public let cornerRadius: CGFloat?
    
    @State private var loadedURL: String?
    @State private var loadedImage: NSImage?
    
    public init(
        urlString: String,
        size: CGFloat = 14,
        fallbackSystemImage: String = "globe",
        cornerRadius: CGFloat? = nil
    ) {
        self.urlString = urlString
        self.size = size
        self.fallbackSystemImage = fallbackSystemImage
        self.cornerRadius = cornerRadius
        
        // Fast-path: Check RAM cache immediately on initialization to render frame 0 with 0ms latency
        if let cached = FaviconService.shared.cachedFavicon(for: urlString) {
            _loadedImage = State(initialValue: cached)
            _loadedURL = State(initialValue: urlString)
        }
    }
    
    public var body: some View {
        Group {
            if let img = displayImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: computedCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: computedCornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: max(8, size * 0.85)))
                    .frame(width: size, height: size)
            }
        }
        .task(id: urlString) {
            guard !urlString.isEmpty else {
                self.loadedImage = nil
                self.loadedURL = nil
                return
            }
            
            // Check RAM cache first
            if let cached = FaviconService.shared.cachedFavicon(for: urlString) {
                self.loadedImage = cached
                self.loadedURL = urlString
                return
            }
            
            // Reset state if view was recycled for a different URL
            if self.loadedURL != urlString {
                self.loadedImage = nil
                self.loadedURL = urlString
            }
            
            if let loaded = await FaviconService.shared.loadFavicon(for: urlString) {
                if !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.loadedImage = loaded
                        self.loadedURL = urlString
                    }
                }
            }
        }
    }
    
    private var computedCornerRadius: CGFloat {
        cornerRadius ?? max(2.5, size * 0.22)
    }
    
    private var displayImage: NSImage? {
        if let cached = FaviconService.shared.cachedFavicon(for: urlString) {
            return cached
        }
        return (loadedURL == urlString) ? loadedImage : nil
    }
}
