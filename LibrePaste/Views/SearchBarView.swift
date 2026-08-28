//
//  SearchBarView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFocused ? Color.accentColor : Color.secondary)
            
            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
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
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
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
