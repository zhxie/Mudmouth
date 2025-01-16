import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.info, "Start tunnel")
        // Configure tunnel.
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        networkSettings.mtu = 1500
        let proxySettings = NEProxySettings()
        if options == nil || options![NEVPNConnectionStartOptionUsername] == nil || options![NEVPNConnectionStartOptionPassword] == nil {
            fatalError("Missing start option")
        }
        // URL and direction are encoded in username.
        let usernameComponents = (options![NEVPNConnectionStartOptionUsername]! as! String).split(separator: ":", maxSplits: 1)
        let url = URL(string: String(usernameComponents[1]))!
        switch url.scheme! {
        case "http":
            proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: ProxyServerPort)
            proxySettings.httpEnabled = true
        case "https":
            proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: ProxyServerPort)
            proxySettings.httpsEnabled = true
        default:
            fatalError("Unexpected scheme: \(url.scheme!)")
        }
        proxySettings.matchDomains = [url.host!]
        networkSettings.proxySettings = proxySettings
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings = ipv4Settings
        let certificateAndPrivateKey = options![NEVPNConnectionStartOptionPassword]! as! String
        let isRequestAndResponse = (Int(usernameComponents[0]) ?? 0) != 0
        setTunnelNetworkSettings(networkSettings) { error in
            os_log(.info, "Match packets against domain %{public}@", url.host!)
            if let error = error {
                fatalError("Failed to configure tunnel: \(error.localizedDescription)")
            }
            // Process packets in the tunnel.
            switch url.scheme! {
            case "http":
                runServer(url: url, isRequestAndResponse: isRequestAndResponse) {
                    completionHandler(nil)
                }
            case "https":
                // Certificate and private key are encoded in password.
                let passwordComponents = certificateAndPrivateKey.split(separator: ":")
                let certificate = Data(base64Encoded: passwordComponents[0].data(using: .utf8)!)!
                let privateKey = Data(base64Encoded: passwordComponents[1].data(using: .utf8)!)!
                runMitmServer(url: url, isRequestAndResponse: isRequestAndResponse, certificate: certificate, privateKey: privateKey) {
                    completionHandler(nil)
                }
            default:
                fatalError("Unexpected scheme: \(url.scheme!)")
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
