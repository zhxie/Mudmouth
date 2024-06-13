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
            return Action(rawValue: preAction) ?? .none
        }
        set {
            preAction = newValue.rawValue
        }
    }
    var postActionEnum: Action {
        get {
            return Action(rawValue: postAction) ?? .none
        }
        set {
            postAction = newValue.rawValue
        }
    }
}
