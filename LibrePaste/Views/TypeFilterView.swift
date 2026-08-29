//
//  TypeFilterView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

public struct TypeFilterView: View {
    @Binding public var selection: FilterType
    public var isCompact: Bool
    
    public init(selection: Binding<FilterType>, isCompact: Bool = false) {
        self._selection = selection
        self.isCompact = isCompact
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(FilterType.allCases) { type in
                let isSelected = selection == type
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = type
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                        
                        if !isCompact {
                            Text(type.displayName)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.horizontal, isCompact ? 7 : 9)
                    .padding(.vertical, 4.5)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.75))
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isSelected
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.clear
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Filter by %@", type.displayName))
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
