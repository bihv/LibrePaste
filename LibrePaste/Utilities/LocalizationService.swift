//
//  LocalizationService.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI

/// Core localization engine for LibrePaste
public final class LocalizationService: @unchecked Sendable {
    public static let shared = LocalizationService()
    
    public static let languageChangedNotification = Notification.Name.languageChanged
    
    private let lock = NSLock()
    private var _currentLanguage: AppLanguage = .system
    private var localizedStringsCache: [String: [String: String]] = [:] // [langCode: [key: value]]
    
    public var currentLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLanguage
        }
        set {
            lock.lock()
            _currentLanguage = newValue
            lock.unlock()
            
            // Set AppleLanguages in UserDefaults for system components
            if let code = newValue.languageCode {
                UserDefaults.standard.set([code], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
            UserDefaults.standard.synchronize()
            
            NotificationCenter.default.post(name: .languageChanged, object: newValue)
        }
    }
    
    public var currentLocale: Locale {
        currentLanguage.locale
    }
    
    private init() {
        loadStringsFromCatalog()
        
        // Load initial language preference
        let savedLang = DatabaseManager.shared.getSetting("appLanguage") ?? AppLanguage.system.rawValue
        if let lang = AppLanguage(rawValue: savedLang) {
            _currentLanguage = lang
        }
    }
    
    /// Parse embedded Localizable.xcstrings or compiled Localizable.strings at runtime
    private func loadStringsFromCatalog() {
        var enDict: [String: String] = [:]
        var viDict: [String: String] = [:]
        
        let bundle = Bundle.main
        
        // 1. Try loading from compiled .lproj folders
        if let enPath = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en") ??
                        bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: "en.lproj") {
            if let dict = NSDictionary(contentsOfFile: enPath) as? [String: String] {
                for (k, v) in dict { enDict[k] = v }
            }
        }
        
        if let viPath = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "vi") ??
                        bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: "vi.lproj") {
            if let dict = NSDictionary(contentsOfFile: viPath) as? [String: String] {
                for (k, v) in dict { viDict[k] = v }
            }
        }
        
        // 2. Try loading from raw Localizable.xcstrings / JSON if present
        if let url = bundle.url(forResource: "Localizable", withExtension: "xcstrings") ??
                     bundle.url(forResource: "Localizable", withExtension: "json") {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let strings = json["strings"] as? [String: [String: Any]] {
                for (key, valDict) in strings {
                    if let localizations = valDict["localizations"] as? [String: [String: Any]] {
                        if let enObj = localizations["en"]?["stringUnit"] as? [String: Any],
                           let enVal = enObj["value"] as? String {
                            enDict[key] = enVal
                        }
                        if let viObj = localizations["vi"]?["stringUnit"] as? [String: Any],
                           let viVal = viObj["value"] as? String {
                            viDict[key] = viVal
                        }
                    }
                }
            }
        }
        
        localizedStringsCache["en"] = enDict
        localizedStringsCache["vi"] = viDict
    }
    
    /// Register preloaded dictionary (used when catalog is compiled into binary)
    public func registerStrings(en: [String: String], vi: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        var currentEn = localizedStringsCache["en"] ?? [:]
        var currentVi = localizedStringsCache["vi"] ?? [:]
        for (k, v) in en { currentEn[k] = v }
        for (k, v) in vi { currentVi[k] = v }
        localizedStringsCache["en"] = currentEn
        localizedStringsCache["vi"] = currentVi
    }
    
    /// Translate a key with optional formatting arguments
    public func localizedString(for key: String, comment: String? = nil, arguments: [CVarArg] = []) -> String {
        let activeLang = currentLanguage
        let langCode: String
        
        switch activeLang {
        case .english:
            langCode = "en"
        case .vietnamese:
            langCode = "vi"
        case .system:
            // Check system preferred language
            let preferred = Locale.preferredLanguages.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
            if preferred.lowercased().starts(with: "vi") {
                langCode = "vi"
            } else {
                langCode = "en"
            }
        }
        
        var template: String? = nil
        
        lock.lock()
        if let dict = localizedStringsCache[langCode], let val = dict[key] {
            template = val
        }
        lock.unlock()
        
        // Fallback to Bundle.main if not in cache
        if template == nil {
            if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let bundleStr = bundle.localizedString(forKey: key, value: nil, table: nil)
                if bundleStr != key {
                    template = bundleStr
                }
            }
        }
        
        let finalTemplate = template ?? key
        if arguments.isEmpty {
            return finalTemplate
        } else {
            return String(format: finalTemplate, locale: activeLang.locale, arguments: arguments)
        }
    }
}

/// Shorthand helper for clean, readable localization throughout the app
public enum L10n {
    public static func tr(_ key: String, comment: String? = nil, _ args: CVarArg...) -> String {
        LocalizationService.shared.localizedString(for: key, comment: comment, arguments: args)
    }
    
    public static var currentLanguage: AppLanguage {
        get { LocalizationService.shared.currentLanguage }
        set { LocalizationService.shared.currentLanguage = newValue }
    }
    
    public static var currentLocale: Locale {
        LocalizationService.shared.currentLocale
    }
}

// SwiftUI Environment Key & View Modifier
private struct AppLocaleKey: EnvironmentKey {
    static let defaultValue: Locale = Locale.autoupdatingCurrent
}

extension EnvironmentValues {
    public var appLocale: Locale {
        get { self[AppLocaleKey.self] }
        set { self[AppLocaleKey.self] = newValue }
    }
}
