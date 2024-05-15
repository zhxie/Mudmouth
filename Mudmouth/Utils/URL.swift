import Foundation
import Network
import SwiftASN1

extension URL {
    var ipv4: ASN1OctetString? {
        let host = self.host!
        guard let ip = IPv4Address(host) else {
            return nil
        }
        return ASN1OctetString(contentBytes: ArraySlice<UInt8>(ip.rawValue))
    }
}
