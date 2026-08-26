//
//  RichTextWYSIWYGEditorView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit
import Combine

public final class RichTextEditorController: ObservableObject {
    public weak var textView: NSTextView?
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    
    public init() {}
    
    public func undo() {
        textView?.undoManager?.undo()
        updateUndoState()
    }
    
    public func redo() {
        textView?.undoManager?.redo()
        updateUndoState()
    }
    
    public func updateUndoState() {
        canUndo = textView?.undoManager?.canUndo ?? false
        canRedo = textView?.undoManager?.canRedo ?? false
    }
    
    public func toggleBold() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let selectedRange = tv.selectedRange()
        let fm = NSFontManager.shared
        
        if selectedRange.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selectedRange, options: []) { val, r, _ in
                let font = (val as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                let newFont: NSFont
                if fm.traits(of: font).contains(.boldFontMask) {
                    newFont = fm.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fm.convert(font, toHaveTrait: .boldFontMask)
                }
                storage.addAttribute(.font, value: newFont, range: r)
            }
            storage.endEditing()
            tv.didChangeText()
        } else {
            var attrs = tv.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
            let newFont: NSFont
            if fm.traits(of: currentFont).contains(.boldFontMask) {
                newFont = fm.convert(currentFont, toNotHaveTrait: .boldFontMask)
            } else {
                newFont = fm.convert(currentFont, toHaveTrait: .boldFontMask)
            }
            attrs[.font] = newFont
            tv.typingAttributes = attrs
        }
    }
    
    public func toggleItalic() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let selectedRange = tv.selectedRange()
        let fm = NSFontManager.shared
        
        if selectedRange.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selectedRange, options: []) { val, r, _ in
                let font = (val as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                let newFont: NSFont
                if fm.traits(of: font).contains(.italicFontMask) {
                    newFont = fm.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fm.convert(font, toHaveTrait: .italicFontMask)
                }
                storage.addAttribute(.font, value: newFont, range: r)
            }
            storage.endEditing()
            tv.didChangeText()
        } else {
            var attrs = tv.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
            let newFont: NSFont
            if fm.traits(of: currentFont).contains(.italicFontMask) {
                newFont = fm.convert(currentFont, toNotHaveTrait: .italicFontMask)
            } else {
                newFont = fm.convert(currentFont, toHaveTrait: .italicFontMask)
            }
            attrs[.font] = newFont
            tv.typingAttributes = attrs
        }
    }
    
    public func toggleUnderline() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let selectedRange = tv.selectedRange()
        
        if selectedRange.length > 0 {
            storage.beginEditing()
            var hasUnderline = false
            storage.enumerateAttribute(.underlineStyle, in: selectedRange, options: []) { val, _, stop in
                if let v = val as? Int, v != 0 {
                    hasUnderline = true
                    stop.pointee = true
                }
            }
            let newVal = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
            storage.addAttribute(.underlineStyle, value: newVal, range: selectedRange)
            storage.endEditing()
            tv.didChangeText()
        } else {
            var attrs = tv.typingAttributes
            let current = (attrs[.underlineStyle] as? Int) ?? 0
            attrs[.underlineStyle] = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
    }
    
    public func toggleStrikethrough() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let selectedRange = tv.selectedRange()
        
        if selectedRange.length > 0 {
            storage.beginEditing()
            var hasStrike = false
            storage.enumerateAttribute(.strikethroughStyle, in: selectedRange, options: []) { val, _, stop in
                if let v = val as? Int, v != 0 {
                    hasStrike = true
                    stop.pointee = true
                }
            }
            let newVal = hasStrike ? 0 : NSUnderlineStyle.single.rawValue
            storage.addAttribute(.strikethroughStyle, value: newVal, range: selectedRange)
            storage.endEditing()
            tv.didChangeText()
        } else {
            var attrs = tv.typingAttributes
            let current = (attrs[.strikethroughStyle] as? Int) ?? 0
            attrs[.strikethroughStyle] = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
    }
    
    public func applyHeading() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let nsString = tv.string as NSString
        let targetRange = range.length > 0 ? range : (nsString.length > 0 ? nsString.lineRange(for: range) : range)
        guard targetRange.length > 0 else { return }
        
        storage.beginEditing()
        let headingFont = NSFont.systemFont(ofSize: 18, weight: .bold)
        storage.addAttribute(.font, value: headingFont, range: targetRange)
        storage.endEditing()
        tv.didChangeText()
    }
    
    public func applySubheading() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let nsString = tv.string as NSString
        let targetRange = range.length > 0 ? range : (nsString.length > 0 ? nsString.lineRange(for: range) : range)
        guard targetRange.length > 0 else { return }
        
        storage.beginEditing()
        let subFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
        storage.addAttribute(.font, value: subFont, range: targetRange)
        storage.endEditing()
        tv.didChangeText()
    }
    
    public func applyBody() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let nsString = tv.string as NSString
        let targetRange = range.length > 0 ? range : (nsString.length > 0 ? nsString.lineRange(for: range) : range)
        guard targetRange.length > 0 else { return }
        
        storage.beginEditing()
        let bodyFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        storage.addAttribute(.font, value: bodyFont, range: targetRange)
        storage.removeAttribute(.underlineStyle, range: targetRange)
        storage.removeAttribute(.strikethroughStyle, range: targetRange)
        storage.endEditing()
        tv.didChangeText()
    }
    
    public func toggleBulletList() {
        guard let tv = textView else { return }
        let selectedRange = tv.selectedRange()
        let nsString = tv.string as NSString
        guard nsString.length > 0 else {
            tv.insertText("• ", replacementRange: NSRange(location: 0, length: 0))
            return
        }
        let lineRange = nsString.lineRange(for: selectedRange)
        let lineText = nsString.substring(with: lineRange)
        if lineText.hasPrefix("• ") {
            let withoutBullet = String(lineText.dropFirst(2))
            tv.insertText(withoutBullet, replacementRange: lineRange)
        } else {
            tv.insertText("• " + lineText, replacementRange: lineRange)
        }
    }
    
    public func clearFormatting() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let selectedRange = tv.selectedRange()
        guard selectedRange.length > 0 else { return }
        
        storage.beginEditing()
        let cleanFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        storage.removeAttribute(.underlineStyle, range: selectedRange)
        storage.removeAttribute(.strikethroughStyle, range: selectedRange)
        storage.addAttribute(.font, value: cleanFont, range: selectedRange)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: selectedRange)
        storage.endEditing()
        tv.didChangeText()
    }
    
    public func exportHTML() -> String {
        guard let tv = textView, let storage = tv.textStorage, storage.length > 0 else {
            return ""
        }
        if let htmlData = try? storage.data(
            from: NSRange(location: 0, length: storage.length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
        ), let html = String(data: htmlData, encoding: .utf8) {
            return html
        }
        return storage.string
    }
    
    public func exportRTF() -> String? {
        guard let tv = textView, let storage = tv.textStorage, storage.length > 0 else {
            return nil
        }
        if let rtfData = try? storage.data(
            from: NSRange(location: 0, length: storage.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            return String(data: rtfData, encoding: .utf8)
        }
        return nil
    }
    
    public func exportPlainText() -> String {
        textView?.string ?? ""
    }
}

public struct RichTextWYSIWYGEditorView: NSViewRepresentable {
    public let attributedString: NSAttributedString
    public let controller: RichTextEditorController
    public let onTextChange: (NSAttributedString) -> Void
    
    public init(
        attributedString: NSAttributedString,
        controller: RichTextEditorController,
        onTextChange: @escaping (NSAttributedString) -> Void
    ) {
        self.attributedString = attributedString
        self.controller = controller
        self.onTextChange = onTextChange
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        
        // Ensure default font if missing
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        if mutable.length == 0 {
            mutable.append(NSAttributedString(
                string: "",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.labelColor
                ]
            ))
        }
        textView.textStorage?.setAttributedString(mutable)
        
        textView.delegate = context.coordinator
        controller.textView = textView
        
        // Auto focus
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // We only maintain internal state via delegate to prevent cursor reset on keystroke
        controller.textView = scrollView.documentView as? NSTextView
    }
    
    public final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: RichTextWYSIWYGEditorView
        
        init(_ parent: RichTextWYSIWYGEditorView) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            parent.controller.updateUndoState()
            parent.onTextChange(NSAttributedString(attributedString: storage))
        }
        
        public func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller.updateUndoState()
        }
    }
}
