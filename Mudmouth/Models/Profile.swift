import Foundation

extension Profile {
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
