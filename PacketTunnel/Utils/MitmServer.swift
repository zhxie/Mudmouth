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
    private var host: String
    private var port: Int
    private var url: URL
    
    private var head: HTTPRequestHead?
    private var body: Data?
    
    private var notificationSent: Bool = false
    
    init(host: String, port: Int, url: URL) {
        self.host = host
        self.port = port
        self.url = url
    }
    
    deinit {
        if httpClient != nil {
            try? httpClient!.syncShutdown()
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        os_log(.debug, "[%{public}@:%d] [DOWN] Read : %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, data.description)
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
                var request = try HTTPClient.Request(url: "https://\(host):\(port)/\(head!.uri)", method: head!.method, headers: head!.headers)
                if body != nil {
                    request.body = .data(body!)
                }
                os_log(.debug, "[%{public}@:%d] [ UP ] Write: %{public}@ %{public}@ %{public}@ %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, head!.method.rawValue, head!.uri, head!.version.description, head!.headers.description)
                httpClient!.execute(request: request).whenComplete { result in
                    switch result {
                    case .success(let response):
                        os_log(.debug, "[%{public}@:%d] [ UP ] Read : %{public}@ %{public}@ %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, response.version.description, response.status.description, response.headers.description)
                        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: response.status, headers: response.headers)
                        context.writeAndFlush(self.wrapOutboundOut(.head(head)), promise: nil)
                        if response.body != nil {
                            context.write(self.wrapOutboundOut(.body(.byteBuffer(response.body!))), promise: nil)
                        }
                        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                        os_log(.debug, "[%{public}@:%d] [Down] Write: %{public}@ %{public}@ %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, response.version.description, response.status.description, response.headers.description)
                        if !self.notificationSent && self.head!.uri == self.url.path {
                            self.notificationSent = true
                            scheduleNotification()
                        }
                    case .failure(let failure):
                        self.httpClient!.shutdown().whenComplete { _ in
                            os_log(.error, "Failed to send request to upstream: %{public}@", failure.localizedDescription)
                            context.close(promise: nil)
                        }
                    }
                }
            } catch {
                httpClient!.shutdown().whenComplete { _ in
                    os_log(.error, "Failed to make request to upstream: %{public}@", error.localizedDescription)
                    context.close(promise: nil)
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
    private var host: String = ""
    private var port: Int = 0
    private var url: URL
    private var tlsConfiguration: TLSConfiguration
    
    init(url: URL, certificate: Data, privateKey: Data) {
        do {
            self.url = url
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
            os_log(.debug, "[%{public}@:%d] [DOWN] Read : %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, data.description)
            let httpData = unwrapInboundIn(data)
            guard case .head(let head) = httpData else {
                return
            }
            guard head.method == .CONNECT else {
                os_log(.error, "Invalid HTTP method: %{public}@", head.method.rawValue)
                context.close(promise: nil)
                return
            }
            let components = head.uri.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            host = String(components.first!)
            port = components.last.flatMap { n in
                Int(n, radix: 10)
            } ?? 80
            os_log(.info, "Target to upstream %{public}@:%d", host, port)
            state = .awaitingEnd
        case .awaitingEnd:
            os_log(.debug, "[%{public}@:%d] [DOWN] Read : %{public}@", context.remoteAddress!.ipAddress!, context.remoteAddress!.port!, data.description)
            let httpData = unwrapInboundIn(data)
            if case .end = httpData {
                do {
                    let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
                    let sslHandler = NIOSSLServerHandler(context: sslContext)
                    // Upgrade to TLS server.
                    context.pipeline.context(handlerType: ByteToMessageHandler<HTTPRequestDecoder>.self).whenSuccess { handler in
                        context.pipeline.removeHandler(context: handler, promise: nil)
                        // Send 200 to downstream.
                        let headers = HTTPHeaders([("Content-Length", "0")])
                        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                        context.pipeline.context(handlerType: HTTPResponseEncoder.self).whenSuccess { handler in
                            context.pipeline.removeHandler(context: handler, promise: nil)
                            context.pipeline.addHandler(sslHandler)
                            .flatMap { _ in
                                context.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                            }
                            .flatMap { _ in
                                context.pipeline.addHandler(HTTPResponseEncoder())
                            }
                            .flatMap { _ in
                                context.pipeline.addHandler(ProxyHandler(host: self.host, port: self.port, url: self.url))
                            }
                            .whenComplete { result in
                                switch result {
                                case .success:
                                    os_log(.info, "Upgraded to TLS server %{public}@:%d", self.host, self.port)
                                    self.state = .established
                                case .failure(let failure):
                                    os_log(.error, "Failed to add TLS handler: %{public}@", failure.localizedDescription)
                                    context.close(promise: nil)
                                }
                            }
                        }
                    }
                } catch {
                    // Send 500 to downstream.
                    let headers = HTTPHeaders([("Content-Length", "0")])
                    let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .internalServerError, headers: headers)
                    context.write(wrapOutboundOut(.head(head)), promise: nil)
                    context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
                    os_log(.error, "Failed to upgrade to TLS server: %{public}@", error.localizedDescription)
                }
            }
        case .established:
            context.fireChannelRead(data)
        }
    }
}

func runMitmServer(url: URL, certificate: Data, privateKey: Data, _ completion: @escaping () -> Void) {
    // Process packets in the tunnel.
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let bootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)), name: "Byte To Message Handler")
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder(), name: "HTTP Response Encoder")
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ConnectHandler(url: url, certificate: certificate, privateKey: privateKey), name: "Connect Handler")
                }
        }
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
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
