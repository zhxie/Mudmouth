import Foundation

extension Date {
    public func format() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm:ss.SSS"
        return formatter.string(from: self)
    }
}
