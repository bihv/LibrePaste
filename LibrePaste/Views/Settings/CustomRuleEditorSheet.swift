//
//  CustomRuleEditorSheet.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct CustomRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private let ruleToEdit: CustomSensitiveRule?
    private let onSave: (CustomSensitiveRule) -> Void
    
    @State private var name: String = ""
    @State private var pattern: String = ""
    @State private var maskStrategy: MaskStrategy = .keepPrefixAndSuffix
    @State private var isCaseSensitive: Bool = false
    @State private var isEnabled: Bool = true
    
    @State private var testSample: String = ""
    
    public init(
        ruleToEdit: CustomSensitiveRule? = nil,
        onSave: @escaping (CustomSensitiveRule) -> Void
    ) {
        self.ruleToEdit = ruleToEdit
        self.onSave = onSave
        
        _name = State(initialValue: ruleToEdit?.name ?? "")
        _pattern = State(initialValue: ruleToEdit?.pattern ?? "")
        _maskStrategy = State(initialValue: ruleToEdit?.maskStrategy ?? .keepPrefixAndSuffix)
        _isCaseSensitive = State(initialValue: ruleToEdit?.isCaseSensitive ?? false)
        _isEnabled = State(initialValue: ruleToEdit?.isEnabled ?? true)
    }
    
    private var validation: (isValid: Bool, errorMessage: String?) {
        SensitiveDataService.shared.validateRegexPattern(pattern)
    }
    
    private var testResult: String {
        guard !testSample.isEmpty, validation.isValid else { return testSample }
        return SensitiveDataService.shared.testMask(
            pattern: pattern,
            strategy: maskStrategy,
            sampleText: testSample,
            isCaseSensitive: isCaseSensitive
        )
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ruleToEdit == nil ? L10n.tr("Add Custom Sensitive Rule") : L10n.tr("Edit Custom Sensitive Rule"))
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.tr("Define regex pattern to detect and mask proprietary tokens or sensitive data."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
                .opacity(0.6)
            
            // 2. Main Content Area (Clean Vertical Stack Layout)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // --- Field: Rule Name ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("Rule Name"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField(L10n.tr("e.g. Company Access Token"), text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                    
                    // --- Field: Regex Pattern ---
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L10n.tr("Regex Pattern"))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !pattern.isEmpty {
                                if validation.isValid {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                        Text(L10n.tr("Valid"))
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                } else if let errorMsg = validation.errorMessage {
                                    HStack(spacing: 3) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                        Text(errorMsg)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        TextField(L10n.tr("e.g. corp_[a-zA-Z0-9]{20,}"), text: $pattern)
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // --- Field: Masking Strategy & Options ---
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("Masking Strategy"))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: $maskStrategy) {
                                ForEach(MaskStrategy.allCases) { item in
                                    Text(item.displayName).tag(item)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("Options"))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                Toggle(L10n.tr("Case Sensitive"), isOn: $isCaseSensitive)
                                    .font(.system(size: 11.5))
                                    .toggleStyle(.checkbox)
                                
                                Toggle(L10n.tr("Enabled"), isOn: $isEnabled)
                                    .font(.system(size: 11.5))
                                    .toggleStyle(.checkbox)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // --- Live Test Sandbox ---
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("Live Test Sandbox"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField(L10n.tr("Type sample text containing the pattern to test..."), text: $testSample)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        
                        if !testSample.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Text(L10n.tr("Preview:"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text(testResult)
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            
            Divider()
                .opacity(0.6)
            
            // 3. Action Buttons
            HStack {
                Button(L10n.tr("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(ruleToEdit == nil ? L10n.tr("Add Rule") : L10n.tr("Save Changes")) {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validation.isValid || pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(width: 440, height: 390)
    }
    
    private func saveRule() {
        let rule = CustomSensitiveRule(
            id: ruleToEdit?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            pattern: pattern.trimmingCharacters(in: .whitespacesAndNewlines),
            maskStrategy: maskStrategy,
            isEnabled: isEnabled,
            isCaseSensitive: isCaseSensitive
        )
        onSave(rule)
        dismiss()
    }
}
