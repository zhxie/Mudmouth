import CoreData
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

enum Direction: Int16, CaseIterable {
    case request = 0
    case requestAndResponse = 1

    var name: String {
        switch self {
        case .request:
            return "Request"
        case .requestAndResponse:
            return "Request & Response"
        }
    }
}

extension Profile {
    convenience init(context: NSManagedObjectContext, queries: [URLQueryItem]) {
        self.init(context: context)
        name =
            queries.first { item in
                item.name == "name"
            }?.value
        url =
            queries.first { item in
                item.name == "url"
            }?.value
        directionEnum =
            Direction(
                rawValue: Int16(
                    queries.first { item in
                        item.name == "direction"
                    }?.value ?? "1") ?? 1) ?? .requestAndResponse
        preActionEnum =
            Action(
                rawValue: Int16(
                    queries.first { item in
                        item.name == "preAction"
                    }?.value ?? "0") ?? 0) ?? .none
        preActionUrlScheme =
            queries.first { item in
                item.name == "preActionUrlScheme"
            }?.value
        postActionEnum =
            Action(
                rawValue: Int16(
                    queries.first { item in
                        item.name == "postAction"
                    }?.value ?? "0") ?? 0) ?? .none
        postActionUrlScheme =
            queries.first { item in
                item.name == "postActionUrlScheme"
            }?.value
    }

    var isValid: Bool {
        if (name ?? "").isEmpty {
            return false
        }
        guard let url = URL(string: url ?? "") else {
            return false
        }
        if url.scheme == nil || (url.scheme! != "http" && url.scheme! != "https") {
            return false
        }
        switch preActionEnum {
        case .none:
            break
        case .urlScheme:
            if URL(string: preActionUrlScheme ?? "") == nil {
                return false
            }
        }
        switch postActionEnum {
        case .none:
            break
        case .urlScheme:
            if URL(string: postActionUrlScheme ?? "") == nil {
                return false
            }
        }
        return true
    }

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

    var directionEnum: Direction {
        get {
            return Direction(rawValue: direction) ?? .request
        }
        set {
            direction = newValue.rawValue
        }
    }
}
