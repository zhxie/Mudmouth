//
//  String.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/29.
//

import Foundation

extension String {
    // Referenced from https://stackoverflow.com/a/57289245.
    func components(withMaxLength length: Int) -> [String] {
        return stride(from: 0, to: count, by: length).map { n in
            let start = index(startIndex, offsetBy: n)
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}
