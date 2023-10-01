//
//  MitmServer.swift
//  PacketTunnel
//
//  Created by Xie Zhihao on 2023/9/30.
//

import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import OSLog

class ProxyHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var httpClient: HTTPClient?
    private var url: URL
    
    private var head: HTTPRequestHead?
    private var body: Data?
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        if httpClient != nil {
            try? httpClient!.syncShutdown()
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        os_log(.debug, "[%{public}@] [DOWN] Read : %{public}@", context.remoteAddress!.description, data.description)
        let httpData = unwrapInboundIn(data)
        switch httpData {
        case .head(let head):
            self.head = head
        case .body(let body):
            if self.body == nil {
                self.body = Data()
            }
            self.body!.reserveCapacity(body.readableBytes)
            let data = body.getData(at: body.readerIndex, length: body.readableBytes)!
            self.body!.append(data)
        case .end:
            if httpClient == nil {
                httpClient = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
            }
            do {
                // Send request to upstream.
                var request = try HTTPClient.Request(url: "https://\(url.host!):\(url.port ?? 443)/\(head!.uri)", method: head!.method, headers: head!.headers)
                if body != nil {
                    request.body = .data(body!)
                }
                os_log(.debug, "[%{public}@] [ UP ] Write: %{public}@ %{public}@ %{public}@", context.remoteAddress!.description, head!.method.rawValue, head!.uri, head!.version.description)
                httpClient!.execute(request: request).whenComplete { result in
                    switch result {
                    case .success(let response):
                        // Send response back to downstream.
                        os_log(.debug, "[%{public}@] [ UP ] Read : %{public}@ %{public}@", context.remoteAddress!.description, response.version.description, response.status.description)
                        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: response.status, headers: response.headers)
                        context.writeAndFlush(self.wrapOutboundOut(.head(head)), promise: nil)
                        if response.body != nil {
                            context.write(self.wrapOutboundOut(.body(.byteBuffer(response.body!))), promise: nil)
                        }
                        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                        os_log(.debug, "[%{public}@] [Down] Write: %{public}@ %{public}@ %{public}@", context.remoteAddress!.description, response.version.description, response.status.description)
                        if self.head!.uri == self.url.path {
                            scheduleNotification(response.headers.description)
                        }
                    case .failure(let failure):
                        self.httpClient!.shutdown().whenComplete { _ in
                            // Send 500 to downstream.
                            let headers = HTTPHeaders([("Content-Length", "0")])
                            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
                            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                            os_log(.error, "Failed to send request to upstream: %{public}@", failure.localizedDescription)
                        }
                    }
                }
            } catch {
                httpClient!.shutdown().whenComplete { _ in
                    // Send 500 to downstream.
                    let headers = HTTPHeaders([("Content-Length", "0")])
                    let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
                    context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                    os_log(.error, "Failed to make request to upstream: %{public}@", error.localizedDescription)
                }
            }
            break
        }
    }
}

class ConnectHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private enum State {
        case idle
        case awaitingEnd
        case established
    }
    
    private var state: State = .idle
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch state {
        case .idle:
            os_log(.debug, "[%{public}@] [DOWN] Read : %{public}@", context.remoteAddress!.description, data.description)
            let httpData = unwrapInboundIn(data)
            guard case .head(let head) = httpData else {
                return
            }
            guard head.method == .CONNECT else {
                os_log(.error, "Invalid HTTP method: %{public}@", head.method.rawValue)
                context.close(promise: nil)
                return
            }
            state = .awaitingEnd
        case .awaitingEnd:
            os_log(.debug, "[%{public}@] [DOWN] Read : %{public}@", context.remoteAddress!.description, data.description)
            let httpData = unwrapInboundIn(data)
            if case .end = httpData {
                // Upgrade to TLS server.
                context.pipeline.context(handlerType: ByteToMessageHandler<HTTPRequestDecoder>.self).whenComplete { result in
                    switch result {
                    case .success(let handler):
                        context.pipeline.removeHandler(context: handler, promise: nil)
                        // Send 200 to downstream.
                        let headers = HTTPHeaders([("Content-Length", "0")])
                        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                        context.pipeline.context(handlerType: HTTPResponseEncoder.self).whenComplete { result in
                            switch result {
                            case .success(let handler):
                                context.pipeline.removeHandler(context: handler, promise: nil)
                                os_log(.info, "Upgraded to TLS server")
                                self.state = .established
                            case .failure(let failure):
                                os_log(.error, "Failed to upgrade to TLS server: %{public}@", failure.localizedDescription)
                                context.close(promise: nil)
                            }
                        }
                    case .failure(let failure):
                        // Send 500 to downstream.
                        let headers = HTTPHeaders([("Content-Length", "0")])
                        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
                        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                        os_log(.error, "Failed to upgrade to TLS server: %{public}@", failure.localizedDescription)
                    }
                }
            }
        case .established:
            // Forward data to next channel.
            context.fireChannelRead(data)
        }
    }
}

func runMitmServer(url: URL, certificate: Data, privateKey: Data, _ completion: @escaping () -> Void) {
    var sslContext: NIOSSLContext?
    do {
        let certificate = try NIOSSLCertificate(bytes: [UInt8](certificate), format: .der)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](privateKey), format: .der)
        let tlsConfiguration = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
        sslContext = try NIOSSLContext(configuration: tlsConfiguration)
    } catch {
        fatalError("Failed to create TLS context: \(error.localizedDescription)")
    }
    // Process packets in the tunnel.
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let bootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ConnectHandler())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext!))
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ProxyHandler(url: url))
                }
        }
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
    bootstrap.bind(to: try! SocketAddress(ipAddress: "127.0.0.1", port: 6836)).whenComplete { result in
        switch result {
        case .success:
            NotificationService.notificationSent = false
            os_log(.info, "MitM proxy binded")
            completion()
        case .failure(let failure):
            fatalError("Failed to bind MitM proxy: \(failure)")
        }
    }
}
