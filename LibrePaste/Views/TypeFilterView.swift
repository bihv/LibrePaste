//
//  TypeFilterView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct TypeFilterView: View {
    @Binding public var selection: FilterType
    
    public init(selection: Binding<FilterType>) {
        self._selection = selection
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
                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                        Text(type.displayName)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
