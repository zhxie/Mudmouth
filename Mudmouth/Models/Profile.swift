import CoreData
import Foundation

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
}
