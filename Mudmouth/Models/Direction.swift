import Foundation

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
    var directionEnum: Direction {
        get {
            return Direction(rawValue: direction) ?? .request
        }
        set {
            direction = newValue.rawValue
        }
    }
}
