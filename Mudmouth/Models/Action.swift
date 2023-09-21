//
//  Action.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import Foundation

enum Action: Int16, CaseIterable {
    case none = 0
    case urlScheme = 1
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .urlScheme:
            return "URL Scheme"
        }
    }
}

extension Profile {
    var preActionEnum: Action {
        get {
            return Action(rawValue: self.preAction) ?? .none
        }
        set {
            self.preAction = newValue.rawValue
        }
    }
    var postActionEnum: Action {
        get {
            return Action(rawValue: self.postAction) ?? .none
        }
        set {
            self.postAction = newValue.rawValue
        }
    }
}
