//
//  Direction.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/10/1.
//

import Foundation

enum Direction: Int16, CaseIterable {
    case request = 0
    case response = 1
    
    var name: String {
        switch self {
        case .request:
            return "Request"
        case .response:
            return "Response"
        }
    }
}

extension Profile {
    var directionEnum: Direction {
        get {
            return Direction(rawValue: direction) ?? .request
        }
        set {
            direction = newValue.rawValue
        }
    }
}
