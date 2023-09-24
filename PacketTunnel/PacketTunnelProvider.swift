//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by Xie Zhihao on 2023/9/21.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("Start tunnel")
        // Configure tunnel.
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        networkSettings.mtu = 1500
        let proxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: 6836)
        proxySettings.httpEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: 6836)
        proxySettings.httpsEnabled = true
        if options == nil || options![NEVPNConnectionStartOptionUsername] == nil {
            fatalError("No match domain")
        }
        let domain = options![NEVPNConnectionStartOptionUsername]! as! String
        let url = URL(string: domain)!
        proxySettings.matchDomains = [url.host!]
        networkSettings.proxySettings = proxySettings
        setTunnelNetworkSettings(networkSettings) { error in
            NSLog("Match packets against domain %@", url.host!)
            if let error = error {
                NSLog("Failed to configure tunnel: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // Process packets in the tunnel.
            completionHandler(nil)
            while true {
                self.packetFlow.readPackets { packets, protocols in
                    NSLog("Read %d packets", packets.count)
                    for i in 0..<packets.count {
                        NSLog("Read v%d packet length %d", protocols[i], packets[i].count)
                    }
                }
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
