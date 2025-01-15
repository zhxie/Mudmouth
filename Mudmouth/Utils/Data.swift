import Foundation

extension Data {
    public func urlSafeBase64EncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public func hex() -> String {
        self.map { char in
            String(format: "%02hhX", char)
        }.joined()
    }
}
