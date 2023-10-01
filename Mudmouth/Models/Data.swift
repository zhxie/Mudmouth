//
//  Data.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/10/1.
//

import Foundation

extension Data {
    public func urlSafeBase64EncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
