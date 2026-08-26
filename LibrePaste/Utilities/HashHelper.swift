//
//  HashHelper.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import CryptoKit

public enum HashHelper {
    public static func sha256(_ string: String) -> String {
        let inputData = Data(string.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public static func sha256(_ data: Data) -> String {
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
