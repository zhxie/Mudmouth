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
        if options == nil || options![NEVPNConnectionStartOptionUsername] == nil {
            fatalError("No match domain")
        }
        let domain = options![NEVPNConnectionStartOptionUsername]! as! String
        let url = URL(string: domain)!
        proxySettings.matchDomains = [url.host!]
        networkSettings.proxySettings = proxySettings
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings = ipv4Settings
        setTunnelNetworkSettings(networkSettings) { error in
            os_log(.info, "Match packets against domain %{public}@", url.host!)
            if let error = error {
                os_log(.error, "Failed to configure tunnel: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // Process packets in the tunnel.
            completionHandler(nil)
            while true {
                self.packetFlow.readPackets { packets, protocols in
                    os_log(.info, "Read %d packets", packets.count)
                    for (i, packet) in packets.enumerated() {
                        os_log(.debug, "Read v%d packet length %d", protocols[i], packet.count)
                    }
                }
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
