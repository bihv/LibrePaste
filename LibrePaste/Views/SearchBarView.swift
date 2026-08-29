//
//  SearchBarView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct SearchBarView: View {
    @Binding public var text: String
    public var isFocusedBinding: Binding<Bool>?
    public var onClear: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(text: Binding<String>, isFocused: Binding<Bool>? = nil, onClear: @escaping () -> Void) {
        self._text = text
        self.isFocusedBinding = isFocused
        self.onClear = onClear
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isFocused ? Color.accentColor : Color.primary.opacity(0.6))
            
            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    isFocusedBinding?.wrappedValue = newValue
                }
                .onChange(of: isFocusedBinding?.wrappedValue) { _, newValue in
                    if let newValue = newValue, newValue != isFocused {
                        isFocused = newValue
                    }
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.14),
                    lineWidth: 1
                )
        )
        .frame(minWidth: 140, maxWidth: 320)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            if let bound = isFocusedBinding?.wrappedValue, bound != isFocused {
                isFocused = bound
            }
        }
    }
}
