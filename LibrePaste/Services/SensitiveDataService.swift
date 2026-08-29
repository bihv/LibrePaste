//
//  SensitiveDataService.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation

public final class SensitiveDataService: @unchecked Sendable {
    public static let shared = SensitiveDataService()
    
    private let lock = NSLock()
    private var customRules: [CustomSensitiveRule] = []
    private var compiledCustomRules: [(rule: CustomSensitiveRule, regex: NSRegularExpression)] = []
    private var cachedSettings: [String: String] = [:]
    
    // MARK: - Precompiled Regex Cache
    
    // 1. API Keys & Tokens
    private let openAIKeyRegex = try? NSRegularExpression(
        pattern: #"\b(sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,})\b"#,
        options: []
    )
    
    private let anthropicKeyRegex = try? NSRegularExpression(
        pattern: #"\b(sk-ant-api[a-zA-Z0-9_-]{30,})\b"#,
        options: []
    )
    
    private let githubTokenRegex = try? NSRegularExpression(
        pattern: #"\b((?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{30,})\b"#,
        options: []
    )
    
    private let awsKeyRegex = try? NSRegularExpression(
        pattern: #"\b((?:AKIA|ASIA|AROA)[0-9A-Z]{16})\b"#,
        options: []
    )
    
    private let stripeKeyRegex = try? NSRegularExpression(
        pattern: #"\b((?:sk|rk)_(?:live|test)_[0-9a-zA-Z]{24,})\b"#,
        options: []
    )
    
    private let googleApiKeyRegex = try? NSRegularExpression(
        pattern: #"\b(AIza[0-9A-Za-z\-_]{35})\b"#,
        options: []
    )
    
    private let slackTokenRegex = try? NSRegularExpression(
        pattern: #"\b(xox[baprs]-[0-9a-zA-Z]{10,48})\b"#,
        options: []
    )
    
    private let jwtTokenRegex = try? NSRegularExpression(
        pattern: #"\b(ey[A-Za-z0-9-_=]{10,}\.[A-Za-z0-9-_=]{10,}(?:\.[A-Za-z0-9-_.+/=]*)?)\b"#,
        options: []
    )
    
    private let privateKeyRegex = try? NSRegularExpression(
        pattern: #"-----BEGIN (?:[A-Z0-9_-]+ )?PRIVATE KEY-----[\s\S]*?-----END (?:[A-Z0-9_-]+ )?PRIVATE KEY-----"#,
        options: []
    )
    
    // 2. Database Connection Schemes & Generic RFC 3986 with credentials
    // Requires credentials (:password@ or user:password@) to avoid false positives on non-sensitive local URLs
    private let dbConnectionRegex = try? NSRegularExpression(
        pattern: #"\b((?:postgres(?:ql)?|mysql|mariadb|mongodb(?:\+srv)?|redis[s]?|sqlserver|mssql|oracle|cockroach(?:db)?|snowflake|clickhouse|amqp[s]?|neo4j(?:\+s)?|elasticsearch|opensearch):\/\/(?:([^:\s\/]+):([^@\s\/]+)@)([^\s\/]+)(?:\/[^\s]*)?)"#,
        options: .caseInsensitive
    )
    
    // Generic credentials in any URI scheme: scheme://user:password@host...
    private let genericUriCredentialsRegex = try? NSRegularExpression(
        pattern: #"\b([a-zA-Z][a-zA-Z0-9+.-]*:\/\/)([^:\s\/]+):([^@\s\/]+)@([^\s\/]+)"#,
        options: .caseInsensitive
    )
    
    // Key-Value style connection strings (e.g. AccountKey=..., password=...)
    private let keyValueSecretRegex = try? NSRegularExpression(
        pattern: #"\b((?:AccountKey|password|pwd|client_secret|api_secret)\s*=\s*)([^;\s]+)"#,
        options: .caseInsensitive
    )
    
    // 3. Financial & Payment Cards (13-19 digits, formatted with spaces/dashes or contiguous)
    private let creditCardRegex = try? NSRegularExpression(
        pattern: #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|2(?:2[2-9][0-9]{2}|[3-6][0-9]{3}|7[01][0-9]{2}|720[0-9])[0-9]{10}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\d{3})\d{11}|(?:[0-9]{4}[-\s]?){3}[0-9]{4})\b"#,
        options: []
    )
    
    // 4. Personal Identifiable Information (PII)
    // Email Address
    private let emailRegex = try? NSRegularExpression(
        pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#,
        options: .caseInsensitive
    )
    
    // Phone Number (International or national formatted with 9 to 15 digits)
    private let phoneRegex = try? NSRegularExpression(
        pattern: #"(?:\+?[0-9]{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}\b"#,
        options: []
    )
    
    // Vietnam CCCD (12 digits with valid 3-digit province prefix)
    private let vnCitizenIdRegex = try? NSRegularExpression(
        pattern: #"\b(0[0-9]{2}[0-3][0-9]{2}[0-9]{6})\b"#,
        options: []
    )
    
    // US SSN (3-2-4 digits)
    private let usSsnRegex = try? NSRegularExpression(
        pattern: #"\b(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b"#,
        options: []
    )
    
    // Authorization Header
    private let authHeaderRegex = try? NSRegularExpression(
        pattern: #"\b((?:Bearer|Basic)\s+)([A-Za-z0-9-_=.+/]{10,})\b"#,
        options: .caseInsensitive
    )
    
    // MARK: - Initialization
    
    private init() {
        // Lightweight initialization with zero cross-singleton dependencies
    }
    
    // MARK: - Settings & Custom Rules Management
    
    public func updateCachedSettings(_ settings: [String: String]) {
        lock.lock()
        self.cachedSettings = settings
        if let jsonString = settings["customSensitiveRules"],
           let data = jsonString.data(using: .utf8),
           let rules = try? JSONDecoder().decode([CustomSensitiveRule].self, from: data) {
            if self.customRules != rules {
                self.customRules = rules
                recompileCustomRulesLocked()
            }
        }
        lock.unlock()
    }
    
    public func loadCustomRules() {
        let jsonString = DatabaseManager.shared.getSetting("customSensitiveRules")
        lock.lock()
        if let jsonString = jsonString,
           let data = jsonString.data(using: .utf8),
           let rules = try? JSONDecoder().decode([CustomSensitiveRule].self, from: data) {
            self.customRules = rules
        } else {
            self.customRules = []
        }
        recompileCustomRulesLocked()
        lock.unlock()
    }
    
    private func recompileCustomRulesLocked() {
        var compiled: [(rule: CustomSensitiveRule, regex: NSRegularExpression)] = []
        for rule in customRules {
            let options: NSRegularExpression.Options = rule.isCaseSensitive ? [] : [.caseInsensitive]
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: options) {
                compiled.append((rule: rule, regex: regex))
            }
        }
        self.compiledCustomRules = compiled
    }
    
    public func getCustomRules() -> [CustomSensitiveRule] {
        lock.lock()
        defer { lock.unlock() }
        return customRules
    }
    
    public func saveCustomRule(_ rule: CustomSensitiveRule) {
        lock.lock()
        var current = customRules
        if let idx = current.firstIndex(where: { $0.id == rule.id }) {
            current[idx] = rule
        } else {
            current.append(rule)
        }
        self.customRules = current
        recompileCustomRulesLocked()
        lock.unlock()
        
        persistCustomRules(current)
    }
    
    public func deleteCustomRule(id: UUID) {
        lock.lock()
        var current = customRules
        current.removeAll { $0.id == id }
        self.customRules = current
        recompileCustomRulesLocked()
        lock.unlock()
        
        persistCustomRules(current)
    }
    
    public func toggleCustomRule(id: UUID, isEnabled: Bool) {
        lock.lock()
        var current = customRules
        if let idx = current.firstIndex(where: { $0.id == id }) {
            current[idx].isEnabled = isEnabled
        }
        self.customRules = current
        recompileCustomRulesLocked()
        lock.unlock()
        
        persistCustomRules(current)
    }
    
    private func persistCustomRules(_ rules: [CustomSensitiveRule]) {
        if let data = try? JSONEncoder().encode(rules),
           let jsonString = String(data: data, encoding: .utf8) {
            DatabaseManager.shared.setSetting(key: "customSensitiveRules", value: jsonString)
        }
    }
    
    public func validateRegexPattern(_ pattern: String) -> (isValid: Bool, errorMessage: String?) {
        guard !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, L10n.tr("Regex pattern cannot be empty."))
        }
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    // MARK: - Testing Sandbox
    
    public func testMask(pattern: String, strategy: MaskStrategy, sampleText: String, isCaseSensitive: Bool = false) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: isCaseSensitive ? [] : [.caseInsensitive]) else {
            return sampleText
        }
        
        let mutableString = NSMutableString(string: sampleText)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        let matches = regex.matches(in: sampleText, options: [], range: fullRange)
        
        guard !matches.isEmpty else {
            return sampleText
        }
        
        // Replace matches in reverse order so character offsets in NSRange remain valid
        for match in matches.reversed() {
            guard match.range.location != NSNotFound,
                  match.range.location + match.range.length <= mutableString.length else {
                continue
            }
            let matchedStr = mutableString.substring(with: match.range)
            let masked = applyMask(to: matchedStr, strategy: strategy)
            mutableString.replaceCharacters(in: match.range, with: masked)
        }
        return mutableString as String
    }
    
    // MARK: - Detection Core Engine
    
    private struct DetectedMatch {
        let range: NSRange
        let maskedSubstring: String
        let type: SensitiveDataType
        let customRuleName: String?
        let priority: Int
    }
    
    /// Detects whether a string contains sensitive data, returning match info and masked preview.
    /// All occurrences of sensitive patterns are identified and masked across the entire text.
    public func detectSensitiveData(in text: String) -> SensitiveMatchResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Guard max scan length to maintain ultra-fast performance on massive files
        let scanText = text.count > 100_000 ? String(text.prefix(100_000)) : text
        let nsText = scanText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        lock.lock()
        var settings = cachedSettings
        var activeCompiledRules = compiledCustomRules.filter { $0.rule.isEnabled }
        let needsInitialLoad = settings.isEmpty
        lock.unlock()
        
        if needsInitialLoad {
            settings = DatabaseManager.shared.getAllSettings()
            lock.lock()
            self.cachedSettings = settings
            if self.customRules.isEmpty,
               let jsonString = settings["customSensitiveRules"],
               let data = jsonString.data(using: .utf8),
               let rules = try? JSONDecoder().decode([CustomSensitiveRule].self, from: data) {
                self.customRules = rules
                recompileCustomRulesLocked()
            }
            activeCompiledRules = self.compiledCustomRules.filter { $0.rule.isEnabled }
            lock.unlock()
        }
        
        let isGlobalMaskingEnabled = (settings["enableSensitiveMasking"] ?? "true") == "true"
        guard isGlobalMaskingEnabled else { return nil }
        
        let maskApiKeys = (settings["maskApiKeys"] ?? "true") == "true"
        let maskCreditCards = (settings["maskCreditCards"] ?? "true") == "true"
        let maskDatabaseUrls = (settings["maskDatabaseUrls"] ?? "true") == "true"
        let maskPII = (settings["maskPII"] ?? "true") == "true"
        
        var discoveredMatches: [DetectedMatch] = []
        
        // 0. User-defined Custom Rules (Highest priority, precompiled)
        for (rule, regex) in activeCompiledRules {
            let matches = regex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matchedSubstring = nsText.substring(with: match.range)
                let masked = applyMask(to: matchedSubstring, strategy: rule.maskStrategy)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .custom,
                    customRuleName: rule.name,
                    priority: 0
                ))
            }
        }
        
        // 1. Private Key (RSA / EC / SSH / PEM)
        if maskApiKeys, let privateKeyRegex = privateKeyRegex {
            let matches = privateKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskPrivateKeyPem(matched)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .privateKey,
                    customRuleName: nil,
                    priority: 1
                ))
            }
        }
        
        // 2. OpenAI API Keys (sk-..., sk-proj-...)
        if maskApiKeys, let openAIKeyRegex = openAIKeyRegex {
            let matches = openAIKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 8, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 2
                ))
            }
        }
        
        // 3. Anthropic API Keys (sk-ant-...)
        if maskApiKeys, let anthropicKeyRegex = anthropicKeyRegex {
            let matches = anthropicKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 7, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 3
                ))
            }
        }
        
        // 4. GitHub Tokens (ghp_..., gho_..., etc.)
        if maskApiKeys, let githubTokenRegex = githubTokenRegex {
            let matches = githubTokenRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 4, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 4
                ))
            }
        }
        
        // 5. AWS Keys (AKIA...)
        if maskApiKeys, let awsKeyRegex = awsKeyRegex {
            let matches = awsKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 4, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 5
                ))
            }
        }
        
        // 6. Stripe Secret Keys (sk_live_...)
        if maskApiKeys, let stripeKeyRegex = stripeKeyRegex {
            let matches = stripeKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 8, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 6
                ))
            }
        }
        
        // 7. Google API Keys (AIza...)
        if maskApiKeys, let googleApiKeyRegex = googleApiKeyRegex {
            let matches = googleApiKeyRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 4, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 7
                ))
            }
        }
        
        // 8. Slack Tokens (xoxb-...)
        if maskApiKeys, let slackTokenRegex = slackTokenRegex {
            let matches = slackTokenRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskApiKey(matched, prefixCount: 5, suffixCount: 4)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .apiKey,
                    customRuleName: nil,
                    priority: 8
                ))
            }
        }
        
        // 9. Database Connections & Secrets
        if maskDatabaseUrls {
            if let dbConnectionRegex = dbConnectionRegex {
                let matches = dbConnectionRegex.matches(in: scanText, options: [], range: fullRange)
                for match in matches {
                    guard match.range.location != NSNotFound,
                          match.range.location + match.range.length <= nsText.length,
                          match.range.length > 0 else { continue }
                    let matched = nsText.substring(with: match.range)
                    let masked = maskDatabaseUrl(matched)
                    discoveredMatches.append(DetectedMatch(
                        range: match.range,
                        maskedSubstring: masked,
                        type: .databaseUrl,
                        customRuleName: nil,
                        priority: 9
                    ))
                }
            }
            
            if let genericUriCredentialsRegex = genericUriCredentialsRegex {
                let matches = genericUriCredentialsRegex.matches(in: scanText, options: [], range: fullRange)
                for match in matches {
                    guard match.range.location != NSNotFound,
                          match.range.location + match.range.length <= nsText.length,
                          match.range.length > 0 else { continue }
                    let matched = nsText.substring(with: match.range)
                    let masked = maskGenericUriCredentials(matched)
                    discoveredMatches.append(DetectedMatch(
                        range: match.range,
                        maskedSubstring: masked,
                        type: .databaseUrl,
                        customRuleName: nil,
                        priority: 10
                    ))
                }
            }
            
            if let keyValueSecretRegex = keyValueSecretRegex {
                let matches = keyValueSecretRegex.matches(in: scanText, options: [], range: fullRange)
                for match in matches {
                    guard match.range.location != NSNotFound,
                          match.range.location + match.range.length <= nsText.length,
                          match.range.length > 0 else { continue }
                    let r1 = match.numberOfRanges > 1 ? match.range(at: 1) : NSRange(location: NSNotFound, length: 0)
                    let prefix = (r1.location != NSNotFound && r1.location + r1.length <= nsText.length) ? nsText.substring(with: r1) : ""
                    let masked = "\(prefix)••••••••••••"
                    discoveredMatches.append(DetectedMatch(
                        range: match.range,
                        maskedSubstring: masked,
                        type: .databaseUrl,
                        customRuleName: nil,
                        priority: 11
                    ))
                }
            }
        }
        
        // 10. Authorization Headers (Bearer <token>)
        if maskApiKeys, let authHeaderRegex = authHeaderRegex {
            let matches = authHeaderRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let r1 = match.numberOfRanges > 1 ? match.range(at: 1) : NSRange(location: NSNotFound, length: 0)
                let r2 = match.numberOfRanges > 2 ? match.range(at: 2) : NSRange(location: NSNotFound, length: 0)
                let prefix = (r1.location != NSNotFound && r1.location + r1.length <= nsText.length) ? nsText.substring(with: r1) : "Bearer "
                let tokenPart = (r2.location != NSNotFound && r2.location + r2.length <= nsText.length) ? nsText.substring(with: r2) : matched
                let masked = maskBearerOrJwtToken(tokenPart, authPrefix: prefix)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .bearerToken,
                    customRuleName: nil,
                    priority: 12
                ))
            }
        }
        
        // 11. Credit Cards (with Luhn check validation to avoid false positives)
        if maskCreditCards, let creditCardRegex = creditCardRegex {
            let matches = creditCardRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let rawCandidate = nsText.substring(with: match.range)
                let sanitizedNumber = rawCandidate.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                
                if sanitizedNumber.count >= 13 && sanitizedNumber.count <= 19 && validateLuhnChecksum(sanitizedNumber) {
                    let last4 = String(sanitizedNumber.suffix(4))
                    let masked = "•••• •••• •••• \(last4)"
                    discoveredMatches.append(DetectedMatch(
                        range: match.range,
                        maskedSubstring: masked,
                        type: .creditCard,
                        customRuleName: nil,
                        priority: 13
                    ))
                }
            }
        }
        
        // 12. JWT Bearer Tokens
        if maskApiKeys, let jwtTokenRegex = jwtTokenRegex {
            let matches = jwtTokenRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskBearerOrJwtToken(matched, authPrefix: "")
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .bearerToken,
                    customRuleName: nil,
                    priority: 14
                ))
            }
        }
        
        // 13. Email Address
        if maskPII, let emailRegex = emailRegex {
            let matches = emailRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let masked = maskEmailAddress(matched)
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .email,
                    customRuleName: nil,
                    priority: 15
                ))
            }
        }
        
        // 14. Phone Number
        if maskPII, let phoneRegex = phoneRegex {
            let matches = phoneRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let digitsOnly = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if digitsOnly.count >= 9 && digitsOnly.count <= 15 {
                    let masked = maskPhoneNumber(matched)
                    discoveredMatches.append(DetectedMatch(
                        range: match.range,
                        maskedSubstring: masked,
                        type: .phoneNumber,
                        customRuleName: nil,
                        priority: 16
                    ))
                }
            }
        }
        
        // 15. Vietnam Citizen ID (CCCD - 12 digits)
        if maskPII, let vnCitizenIdRegex = vnCitizenIdRegex {
            let matches = vnCitizenIdRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let last4 = String(matched.suffix(4))
                let masked = "•••• •••• \(last4)"
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .nationalId,
                    customRuleName: nil,
                    priority: 17
                ))
            }
        }
        
        // 16. US SSN (9 digits formatted)
        if maskPII, let usSsnRegex = usSsnRegex {
            let matches = usSsnRegex.matches(in: scanText, options: [], range: fullRange)
            for match in matches {
                guard match.range.location != NSNotFound,
                      match.range.location + match.range.length <= nsText.length,
                      match.range.length > 0 else { continue }
                let matched = nsText.substring(with: match.range)
                let last4 = String(matched.suffix(4))
                let masked = "•••-••-\(last4)"
                discoveredMatches.append(DetectedMatch(
                    range: match.range,
                    maskedSubstring: masked,
                    type: .nationalId,
                    customRuleName: nil,
                    priority: 18
                ))
            }
        }
        
        guard !discoveredMatches.isEmpty else { return nil }
        
        // Resolve overlaps: prioritize higher rule priority (lower number), then longer matches
        let sortedCandidates = discoveredMatches.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.range.length > $1.range.length
        }
        
        var nonOverlapping: [DetectedMatch] = []
        for candidate in sortedCandidates {
            let cStart = candidate.range.location
            let cEnd = candidate.range.location + candidate.range.length
            
            let overlaps = nonOverlapping.contains { existing in
                let eStart = existing.range.location
                let eEnd = existing.range.location + existing.range.length
                return max(cStart, eStart) < min(cEnd, eEnd)
            }
            
            if !overlaps {
                nonOverlapping.append(candidate)
            }
        }
        
        guard !nonOverlapping.isEmpty else { return nil }
        
        // Replace all matches from back-to-front so character offsets in NSRange remain valid
        let mutableString = NSMutableString(string: scanText)
        let sortedForReplacement = nonOverlapping.sorted { $0.range.location > $1.range.location }
        
        for match in sortedForReplacement {
            guard match.range.location != NSNotFound,
                  match.range.location + match.range.length <= mutableString.length else {
                continue
            }
            mutableString.replaceCharacters(in: match.range, with: match.maskedSubstring)
        }
        
        let maskedFull = (mutableString as String).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Determine whether multiple distinct sensitive categories matched
        let distinctTypes = Set(nonOverlapping.map { $0.type })
        let primaryMatch = nonOverlapping.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.range.location < $1.range.location
        }.first!
        
        let finalType: SensitiveDataType
        let finalCustomRuleName: String?
        if distinctTypes.count > 1 {
            finalType = .mixed
            finalCustomRuleName = nil
        } else {
            finalType = primaryMatch.type
            finalCustomRuleName = primaryMatch.customRuleName
        }
        
        let primaryMatchedSubstring = nsText.substring(with: primaryMatch.range)
        
        return SensitiveMatchResult(
            type: finalType,
            matchedSubstring: primaryMatchedSubstring,
            maskedPreview: maskedFull,
            customRuleName: finalCustomRuleName
        )
    }
    
    // MARK: - Masking Helpers
    
    private func maskEmailAddress(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else {
            return applyMask(to: email, strategy: .keepPrefixAndSuffix)
        }
        let userPart = String(email[..<atIndex])
        let domainPart = String(email[atIndex...])
        
        if userPart.count <= 2 {
            return "\(String(userPart.prefix(1)))••\(domainPart)"
        }
        let head = String(userPart.prefix(1))
        let tail = String(userPart.suffix(1))
        return "\(head)••••\(tail)\(domainPart)"
    }
    
    private func maskPhoneNumber(_ rawPhone: String) -> String {
        let digitsOnly = rawPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digitsOnly.count >= 4 {
            let last4 = String(digitsOnly.suffix(4))
            return "•••• •••• \(last4)"
        }
        return "••••••••"
    }
    
    public func applyMask(to text: String, strategy: MaskStrategy) -> String {
        let count = text.count
        guard count > 0 else { return "" }
        
        switch strategy {
        case .maskAll:
            let bulletCount = min(max(count, 8), 24)
            return String(repeating: "•", count: bulletCount)
            
        case .keepSuffixOnly:
            if count <= 4 {
                return String(repeating: "•", count: count)
            }
            let suffix = String(text.suffix(4))
            return "••••••••\(suffix)"
            
        case .keepPrefixAndSuffix:
            if count <= 8 {
                return String(repeating: "•", count: count)
            }
            let prefixCount = min(count / 4, 6)
            let prefix = String(text.prefix(prefixCount))
            let suffix = String(text.suffix(4))
            return "\(prefix)••••••••\(suffix)"
        }
    }
    
    private func maskPrivateKeyPem(_ pemString: String) -> String {
        let lines = pemString.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let beginLine = lines.first { $0.hasPrefix("-----BEGIN") } ?? "-----BEGIN RSA PRIVATE KEY-----"
        let endLine = lines.last { $0.hasPrefix("-----END") } ?? "-----END RSA PRIVATE KEY-----"
        
        return """
        \(beginLine)
        ••••••••••••••••••••••••••••••••••••••••••••••••
        ••••••••••••••••••••••••••••••••••••••••••••••••
        \(endLine)
        """
    }
    
    private func maskBearerOrJwtToken(_ token: String, authPrefix: String = "") -> String {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = cleanToken.count
        guard count > 0 else { return "\(authPrefix)••••••••••••" }
        
        // If JWT format (Header.Payload.Signature)
        if cleanToken.hasPrefix("ey") && cleanToken.contains(".") {
            let parts = cleanToken.components(separatedBy: ".")
            if parts.count >= 2 {
                let headerPrefix = String(parts[0].prefix(min(parts[0].count, 10)))
                let signatureTail = String(cleanToken.suffix(min(count, 6)))
                return "\(authPrefix)\(headerPrefix)••••••••••••\(signatureTail)"
            }
        }
        
        if count <= 6 {
            return "\(authPrefix)••••••••"
        }
        
        if count <= 12 {
            let head = String(cleanToken.prefix(min(count, 2)))
            return "\(authPrefix)\(head)••••••••"
        }
        
        let prefixCount = min(max(count / 6, 4), 8)
        let suffixCount = min(max(count / 10, 4), 6)
        
        if count > (prefixCount + suffixCount) {
            let head = String(cleanToken.prefix(prefixCount))
            let tail = String(cleanToken.suffix(suffixCount))
            return "\(authPrefix)\(head)••••••••••••\(tail)"
        } else {
            let head = String(cleanToken.prefix(min(count / 3, 4)))
            let tail = String(cleanToken.suffix(min(count / 3, 4)))
            return "\(authPrefix)\(head)••••••••\(tail)"
        }
    }
    
    private func maskApiKey(_ key: String, prefixCount: Int = 6, suffixCount: Int = 4) -> String {
        let count = key.count
        guard count > (prefixCount + suffixCount) else {
            return String(repeating: "•", count: min(count, 16))
        }
        let prefix = String(key.prefix(prefixCount))
        let suffix = String(key.suffix(suffixCount))
        return "\(prefix)••••••••••••\(suffix)"
    }
    
    private func maskDatabaseUrl(_ urlString: String) -> String {
        // Find password in URI: scheme://user:PASSWORD@host...
        guard let atIndex = urlString.range(of: "@") else {
            return urlString
        }
        let beforeAt = String(urlString[..<atIndex.lowerBound])
        let afterAt = String(urlString[atIndex.lowerBound...])
        
        if let colonIndex = beforeAt.range(of: ":", options: .backwards) {
            let schemeAndUser = String(beforeAt[..<colonIndex.upperBound])
            return "\(schemeAndUser)••••••••••••\(afterAt)"
        }
        return urlString
    }
    
    private func maskGenericUriCredentials(_ uriString: String) -> String {
        guard let atIndex = uriString.range(of: "@") else {
            return uriString
        }
        let beforeAt = String(uriString[..<atIndex.lowerBound])
        let afterAt = String(uriString[atIndex.lowerBound...])
        
        if let colonIndex = beforeAt.range(of: ":", options: .backwards) {
            let schemeAndUser = String(beforeAt[..<colonIndex.upperBound])
            return "\(schemeAndUser)••••••••••••\(afterAt)"
        }
        return uriString
    }
    
    private func maskFullText(text: String, matchRange: NSRange, maskedSubstring: String) -> String {
        let nsText = text as NSString
        guard matchRange.location != NSNotFound,
              matchRange.location + matchRange.length <= nsText.length else {
            return maskedSubstring
        }
        let fullMasked = nsText.replacingCharacters(in: matchRange, with: maskedSubstring)
        return fullMasked.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Luhn Algorithm
    
    public func validateLuhnChecksum(_ number: String) -> Bool {
        let digits = number.compactMap { Int(String($0)) }
        guard digits.count >= 13 else { return false }
        
        var sum = 0
        let reversedDigits = digits.reversed()
        
        for (index, digit) in reversedDigits.enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? (doubled - 9) : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }
}
