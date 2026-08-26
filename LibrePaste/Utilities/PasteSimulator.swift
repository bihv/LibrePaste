//
//  PasteSimulator.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Cocoa
import ApplicationServices

public final class PasteSimulator {
    public static let shared = PasteSimulator()
    
    private init() {}
    
    /// Write clip to pasteboard (with rich formatting / image / link)
    public func writeClipToClipboard(_ clip: ClipRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch clip.type {
        case .image:
            if let imagePath = clip.imagePath {
                if let image = NSImage(contentsOfFile: imagePath) {
                    pasteboard.writeObjects([image])
                }
                let fileUrl = URL(fileURLWithPath: imagePath)
                let ext = fileUrl.pathExtension.lowercased()
                if let data = try? Data(contentsOf: fileUrl) {
                    switch ext {
                    case "png":
                        pasteboard.setData(data, forType: .png)
                    case "jpg", "jpeg":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.jpeg"))
                    case "gif":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
                    case "heic":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.heic"))
                    case "webp":
                        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("org.webmproject.webp"))
                    default:
                        break
                    }
                }
            }
        case .richtext:
            var wrote = false
            if let rtf = clip.rtf, let rtfData = rtf.data(using: .utf8) {
                pasteboard.setData(rtfData, forType: .rtf)
                wrote = true
            }
            if clip.content.contains("<") && clip.content.contains(">"),
               let htmlData = clip.content.data(using: .utf8) {
                pasteboard.setData(htmlData, forType: .html)
                wrote = true
            }
            let plain: String
            if clip.content.contains("<") && clip.content.contains(">") {
                plain = clip.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                plain = clip.content
            }
            pasteboard.setString(plain, forType: .string)
        case .link:
            if let url = URL(string: clip.content) {
                pasteboard.writeObjects([url as NSURL])
            }
            pasteboard.setString(clip.content, forType: .string)
        case .text:
            pasteboard.setString(clip.content, forType: .string)
        }
    }
    
    /// Write clip as plain text only
    public func writeClipAsPlainText(_ clip: ClipRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if clip.type == .image {
            return
        }
        let plain: String
        if clip.type == .richtext && clip.content.contains("<") && clip.content.contains(">") {
            plain = clip.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            plain = clip.content
        }
        pasteboard.setString(plain, forType: .string)
    }
    
    /// Simulate Cmd+V keystroke into previous application
    public func simulatePaste(targetAppBundleId: String? = nil, completion: (() -> Void)? = nil) {
        // Find target application to activate
        var appToActivate: NSRunningApplication? = nil
        if let bundleId = targetAppBundleId {
            appToActivate = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
        }
        
        // Fallback: If target app not found, pick the most recent regular application that is not LibrePaste
        if appToActivate == nil {
            appToActivate = NSWorkspace.shared.runningApplications.first {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier &&
                !$0.isTerminated
            }
        }
        
        // Activate the target application
        appToActivate?.activate(options: [.activateIgnoringOtherApps])
        
        // Delay to allow target window to focus before simulating keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard PasteSimulator.isAccessibilityGranted() else {
                print("[PasteSimulator] Accessibility permission is NOT granted. Prompting user...")
                PasteSimulator.requestAccessibilityPermissions()
                completion?()
                return
            }
            
            // Key code for 'V' is 9 (kVK_ANSI_V)
            let vKeyCode: CGKeyCode = 9
            guard let source = CGEventSource(stateID: .combinedSessionState) else {
                print("[PasteSimulator] Failed to create CGEventSource")
                completion?()
                return
            }
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
                print("[PasteSimulator] Failed to create CGEvent")
                completion?()
                return
            }
            
            // Set Command modifier flags on both key down and key up
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            
            print("[PasteSimulator] Successfully simulated ⌘V into: \(appToActivate?.localizedName ?? "unknown")")
            completion?()
        }
    }
    
    /// Check if Accessibility permissions are granted without caching
    public static func isAccessibilityGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Prompt user for Accessibility permissions if not granted
    public static func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
