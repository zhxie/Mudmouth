//
//  MitmServer.swift
//  PacketTunnel
//
//  Created by Xie Zhihao on 2023/9/30.
//

import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import OSLog

class ConnectHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    
    private enum State {
        case idle
        case established
    }
    
    private var state: State = .idle
    private var host: String = ""
    private var port: Int = 0
    private var tlsConfiguration: TLSConfiguration
    
    init(certificate: Data, privateKey: Data) {
        do {
            let certificate = try NIOSSLCertificate(bytes: [UInt8](certificate), format: .der)
            let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](privateKey), format: .der)
            tlsConfiguration = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
        } catch {
            fatalError("Failed to create TLS configuration: \(error)")
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch state {
        case .idle:
            let httpData = unwrapInboundIn(data)
            guard case .head(let head) = httpData else {
                return
            }
            guard head.method == .CONNECT else {
                os_log(.error, "Invalid HTTP method: %{public}@", head.method.rawValue)
                return
            }
            let components = head.uri.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            host = String(components.first!)
            port = components.last.flatMap { n in
                Int(n, radix: 10)
            } ?? 80
            do {
                let sslContext = try NIOSSLContext(configuration: self.tlsConfiguration)
                let sslHandler = NIOSSLServerHandler(context: sslContext)
                // Send 200 to downstream.
                let headers = HTTPHeaders([("Content-Length", "0")])
                let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                // Upgrade to TLS server.
                let _ = context.pipeline.addHandler(sslHandler, position: .first)
                os_log(.info, "Upgraded to TLS server %{public}@:%d", host, port)
                self.state = .established
            } catch {
                // Send 500 to downstream.
                let headers = HTTPHeaders([("Content-Length", "0")])
                let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                os_log(.info, "Failed to upgrade to TLS server: %{public}@", error.localizedDescription)
            }
        case .established:
            os_log(.info, "%{public}@", data.description)
            break
        }
    }
}

func runMitmServer(certificate: Data, privateKey: Data, _ completion: @escaping () -> Void) {
    // Process packets in the tunnel.
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let bootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ConnectHandler(certificate: certificate, privateKey: privateKey))
                }
        }
    bootstrap.bind(to: try! SocketAddress(ipAddress: "127.0.0.1", port: 6836)).whenComplete { result in
        switch result {
        case .success:
            os_log(.info, "MitM proxy binded")
            completion()
        case .failure(let failure):
            fatalError("Failed to bind MitM proxy: \(failure)")
        }
    }
}
