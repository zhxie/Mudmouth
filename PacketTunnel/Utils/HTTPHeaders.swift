import Foundation
import NIOHTTP1

extension HTTPHeaders {
    var readable: String {
        var result = ""
        let _ = self.map { name, value in
            if !result.isEmpty {
                result.append("\r\n")
            }
            result.append("\(name): \(value)")
        }
        return result
    }
}
