//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by Xie Zhihao on 2023/9/21.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.info, "Start tunnel")
        // Configure tunnel.
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        networkSettings.mtu = 1500
        let proxySettings = NEProxySettings()
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: 6836)
        proxySettings.httpsEnabled = true
        if options == nil || options![NEVPNConnectionStartOptionUsername] == nil || options![NEVPNConnectionStartOptionPassword] == nil {
            fatalError("No match domain")
        }
        if options![NEVPNConnectionStartOptionPassword] == nil {
            fatalError("No certificate and private key")
        }
        let domain = options![NEVPNConnectionStartOptionUsername]! as! String
        let url = URL(string: domain)!
        proxySettings.matchDomains = [url.host!]
        networkSettings.proxySettings = proxySettings
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings = ipv4Settings
        let certificateAndPrivateKey = options![NEVPNConnectionStartOptionPassword]! as! String
        let components = certificateAndPrivateKey.split(separator: ":")
        let certificate = Data(base64Encoded: components[0].data(using: .utf8)!)!
        let privateKey = Data(base64Encoded: components[1].data(using: .utf8)!)!
        setTunnelNetworkSettings(networkSettings) { error in
            os_log(.info, "Match packets against domain %{public}@", url.host!)
            if let error = error {
                fatalError("Failed to configure tunnel: \(error.localizedDescription)")
            }
            // Process packets in the tunnel.
            runMitmServer(certificate: certificate, privateKey: privateKey) {
                completionHandler(nil)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
