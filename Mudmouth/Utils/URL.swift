import Foundation
import SwiftASN1

extension URL {
    var ipv4: ASN1OctetString? {
        let host = self.host!
        let sections = host.split(separator: ".")
        var octets: [UInt8] = []
        for section in sections {
            let octet = UInt8(section)
            if octet == nil {
                return nil
            }
            octets.append(octet!)
        }
        if octets.count != 4 {
            return nil
        }
        return ASN1OctetString(contentBytes: octets.prefix(upTo: 4))
    }
}
