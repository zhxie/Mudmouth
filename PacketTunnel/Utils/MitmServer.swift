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
import OSLog

class ConnectHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    
    private enum State {
        case idle
        case awaitingEnd
        case established
    }
    
    private var state: State = .idle
    private var host: String = ""
    private var port: Int = 0
    private var certificateData: Data
    private var privateKeyData: Data
    
    init(certificate: Data, privateKey: Data) {
        certificateData = certificate
        privateKeyData = privateKey
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch state {
        case .idle:
            let httpData = unwrapInboundIn(data)
            guard case .head(let head) = httpData else {
                os_log(.error, "Invalid HTTP message: %{public}@", data.description)
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
            os_log(.info, "Target to upstream: %{public}@:%d", host, port)
            state = .awaitingEnd
        case .awaitingEnd:
            let httpData = unwrapInboundIn(data)
            if case .end = httpData {
                context.pipeline.context(handlerType: ByteToMessageHandler<HTTPRequestDecoder>.self).whenSuccess { c in
                    context.pipeline.removeHandler(context: c, promise: nil)
                    // Send 200 to downstream.
                    let headers = HTTPHeaders([("Content-Length", "0")])
                    let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                    context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                    context.pipeline.context(handlerType: HTTPResponseEncoder.self).whenSuccess { c in
                        context.pipeline.removeHandler(context: c, promise: nil)
                        os_log(.info, "Complete HTTP CONNECT handling")
                        self.state = .established
                    }
                }
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
            completion()
        case .failure(let failure):
            fatalError("Failed to bind MitM proxy \(failure)")
        }
    }
}
