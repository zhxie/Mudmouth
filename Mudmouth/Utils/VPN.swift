//
//  VPN.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/29.
//

import Foundation
import NetworkExtension
import OSLog

func installVpn() {
    let manager = NETunnelProviderManager()
    manager.localizedDescription = "Mudmouth"
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "name.sketch.Mudmouth.PacketTunnel"
    proto.serverAddress = "Mudmouth"
    manager.protocolConfiguration = proto
    manager.isEnabled = true
    manager.saveToPreferences { error in
        if let error = error {
            fatalError("Failed to add VPN profile: \(error.localizedDescription)")
        }
    }
}

func loadVpn(_ completion: @escaping (_ manager: NETunnelProviderManager?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
        if let error = error {
            fatalError("Failed to load VPN profile: \(error.localizedDescription)")
        }
        os_log(.info, "Load %d VPN profile", managers?.count ?? 0)
        let manager = managers?.first
        completion(manager)
    }
}

func startVpn(manager: NETunnelProviderManager, url: String, certificate: [UInt8], privateKey: Data, _ completion: @escaping () -> Void) {
    manager.isEnabled = true
    manager.saveToPreferences { error in
        if let error = error {
            fatalError("Failed to enable VPN: \(error.localizedDescription)")
        }
        do {
            try manager.connection.startVPNTunnel(options: [
                NEVPNConnectionStartOptionUsername: url as NSObject,
                NEVPNConnectionStartOptionPassword: "\(Data(certificate).base64EncodedString()):\(privateKey.base64EncodedString())" as NSObject
            ])
            completion()
        } catch {
            fatalError("Failed to start VPN: \(error.localizedDescription)")
        }
    }
}
