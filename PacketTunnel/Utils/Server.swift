import DequeModule
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import OSLog

// Referenced from https://github.com/apple/swift-nio-examples.
class GlueHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOAny
    typealias OutboundIn = NIOAny
    typealias OutboundOut = NIOAny

    private var partner: GlueHandler?
    private var context: ChannelHandlerContext?
    private var pendingRead: Bool = false

    static func matchedPair() -> (GlueHandler, GlueHandler) {
        let first = GlueHandler()
        let second = GlueHandler()

        first.partner = second
        second.partner = first

        return (first, second)
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
    }
    func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil
        partner = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        partner?.partnerWrite(data)
    }
    func channelReadComplete(context: ChannelHandlerContext) {
        partner?.partnerFlush()
    }
    func channelInactive(context: ChannelHandlerContext) {
        partner?.partnerCloseFull()
    }
    func channelWritabilityChanged(context: ChannelHandlerContext) {
        if context.channel.isWritable {
            partner?.partnerBecameWritable()
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, case .inputClosed = event {
            partner?.partnerWriteEOF()
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        partner?.partnerCloseFull()
    }

    func read(context: ChannelHandlerContext) {
        if let partner = partner, partner.partnerWritable {
            context.read()
        } else {
            pendingRead = true
        }
    }

    private func partnerWrite(_ data: NIOAny) {
        context?.write(data, promise: nil)
    }
    private func partnerFlush() {
        context?.flush()
    }
    private func partnerWriteEOF() {
        context?.close(mode: .output, promise: nil)
    }
    private func partnerCloseFull() {
        context?.close(promise: nil)
    }
    private func partnerBecameWritable() {
        if pendingRead {
            pendingRead = false
            context?.read()
        }
    }

    private var partnerWritable: Bool {
        context?.channel.isWritable ?? false
    }
}

class ProxyHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPClientRequestPart
    typealias OutboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPServerResponsePart

    private var url: URL
    private var isRequestAndResponse: Bool
    private var persistenceController: PersistenceController

    private var requests: Deque<HTTPRequest> = []
    private var response: HTTPResponse?

    init(url: URL, isRequestAndResponse: Bool, persistenceController: PersistenceController) {
        self.url = url
        self.isRequestAndResponse = isRequestAndResponse
        self.persistenceController = persistenceController
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        os_log(.debug, "[%{public}@] Read: %{public}@", context.remoteAddress!.description, data.description)
        let httpData = unwrapInboundIn(data)
        switch httpData {
        case .head(let head):
            requests.append(HTTPRequest(head: head))
            context.fireChannelRead(wrapInboundOut(.head(head)))
        case .body(let body):
            requests.last!.appendBody(body)
            context.fireChannelRead(wrapInboundOut(.body(.byteBuffer(body))))
        case .end:
            let head = requests.last!.head
            if !isRequestAndResponse {
                let recordURL = head.uri.starts(with: "http") ? head.uri : "\(url.scheme!)://\(url.host!)\(head.uri)"
                let _ = Record(context: persistenceController.container.viewContext, url: recordURL, method: head.method, requestHeaders: head.headers.readable)
                do {
                    try persistenceController.container.viewContext.save()
                } catch {
                    os_log(.error, "Failed to save context: %{public}@", error.localizedDescription)
                }
                if head.uri == url.path {
                    scheduleNotification(requestHeaders: head.headers.readable, responseHeaders: nil)
                }
            }
            context.fireChannelRead(wrapInboundOut(.end(nil)))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        os_log(.debug, "[%{public}@] Write: %{public}@", context.remoteAddress!.description, data.description)
        let httpData = unwrapOutboundIn(data)
        switch httpData {
        case .head(let head):
            response = HTTPResponse(head: head)
            context.write(wrapOutboundOut(.head(head)), promise: promise)
        case .body(let body):
            response!.appendBody(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: promise)
        case .end:
            let request = requests.popFirst()!
            let prefix = "\(url.scheme!)://\(url.host!)"
            if isRequestAndResponse {
                let recordURL = request.head.uri.starts(with: "http") ? request.head.uri : "\(url.scheme!)://\(url.host!)\(request.head.uri)"
                let _ = Record(context: persistenceController.container.viewContext, url: recordURL, method: request.head.method, requestHeaders: request.head.headers.readable, status: response!.head.status, responseHeaders: response!.head.headers.readable)
                do {
                    try persistenceController.container.viewContext.save()
                } catch {
                    os_log(.error, "Failed to save context: %{public}@", error.localizedDescription)
                }
                if request.head.uri == url.path || request.head.uri.hasPrefix(prefix) && String(request.head.uri.dropFirst(prefix.count)) == url.path {
                    scheduleNotification(requestHeaders: request.head.headers.readable, responseHeaders: response!.head.headers.readable)
                }
            }
            response = nil
            context.write(wrapOutboundOut(.end(nil)), promise: promise)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        os_log(.debug, "[%{public}@] Close", context.remoteAddress!.description)
    }
}

class HTTPSConnectHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private enum State {
        case idle
        case awaitingEnd
        case established
    }

    private var state: State = .idle
    private var host: String?
    private var port: Int?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch state {
        case .idle:
            os_log(.debug, "[%{public}@] Read: %{public}@", context.remoteAddress!.description, data.description)
            let httpData = unwrapInboundIn(data)
            guard case .head(let head) = httpData else {
                return
            }
            guard head.method == .CONNECT else {
                os_log(.error, "Invalid HTTP method: %{public}@", head.method.rawValue)
                // Send 405 to downstream.
                let headers = HTTPHeaders([("Content-Length", "0")])
                let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .methodNotAllowed, headers: headers)
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                return
            }
            let components = head.uri.split(separator: ":")
            host = String(components[0])
            port = Int(components[1])!
            state = .awaitingEnd
        case .awaitingEnd:
            os_log(.debug, "[%{public}@] Read: %{public}@", context.remoteAddress!.description, data.description)
            let httpData = unwrapInboundIn(data)
            if case .end = httpData {
                // Upgrade to TLS server.
                context.pipeline.context(handlerType: ByteToMessageHandler<HTTPRequestDecoder>.self).whenSuccess { handler in
                    context.pipeline.removeHandler(context: handler, promise: nil)
                    ClientBootstrap(group: context.eventLoop)
                        .channelInitializer { channel in
                            let clientConfiguration = TLSConfiguration.makeClientConfiguration()
                            let sslClientContext = try! NIOSSLContext(configuration: clientConfiguration)
                            return channel.pipeline.addHandler(
                                try! NIOSSLClientHandler(context: sslClientContext, serverHostname: self.host!)
                            )
                            .flatMap { _ in
                                channel.pipeline.addHandler(HTTPRequestEncoder())
                            }
                            .flatMap { _ in
                                channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes)))
                            }
                        }
                        .connect(host: self.host!, port: self.port!)
                        .whenComplete { result in
                            switch result {
                            case .success(let client):
                                os_log(.info, "Connected to upstream %{public}@:%d", self.host!, self.port!)
                                // Send 200 to downstream.
                                let headers = HTTPHeaders([("Content-Length", "0")])
                                let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
                                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                                context.pipeline.context(handlerType: HTTPResponseEncoder.self).whenSuccess { handler in
                                    context.pipeline.removeHandler(context: handler, promise: nil)
                                    let (localGlue, remoteGlue) = GlueHandler.matchedPair()
                                    context.pipeline.addHandler(localGlue)
                                        .and(client.pipeline.addHandler(remoteGlue))
                                        .whenComplete { result in
                                            switch result {
                                            case .success:
                                                os_log(.info, "Upgraded to HTTPS proxy server")
                                                self.state = .established
                                            case .failure(let failure):
                                                os_log(.error, "Failed to upgrade to HTTPS proxy server: %{public}@", failure.localizedDescription)
                                                context.close(promise: nil)
                                            }
                                        }
                                }
                            case .failure(let failure):
                                // Send 404 to downstream.
                                let headers = HTTPHeaders([("Content-Length", "0")])
                                let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .notFound, headers: headers)
                                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                                os_log(.error, "Failed to connect to upstream %{public}@:%d@: %{public}@", self.host!, self.port!, failure.localizedDescription)
                            }
                        }
                }
            }
        case .established:
            // Forward data to the next channel.
            context.fireChannelRead(data)
        }
    }
}

class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private var connected: Bool = false
    private var buffer = ByteBuffer()
    private var host: String
    private var port: Int

    init(url: URL) {
        self.host = url.host!
        self.port = url.port ?? 80
    }

    func channelRegistered(context: ChannelHandlerContext) {
        ClientBootstrap(group: context.eventLoop)
            .channelInitializer { channel in
                return channel.pipeline.addHandler(HTTPRequestEncoder())
                    .flatMap { _ in
                        channel.pipeline.addHandler(
                            ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes)))
                    }
            }
            .connect(host: host, port: port)
            .whenComplete { result in
                switch result {
                case .success(let client):
                    os_log(.info, "Connected to upstream %{public}@:%d", self.host, self.port)
                    let (localGlue, remoteGlue) = GlueHandler.matchedPair()
                    context.pipeline.addHandler(localGlue)
                        .and(client.pipeline.addHandler(remoteGlue))
                        .whenComplete { result in
                            switch result {
                            case .success:
                                self.connected = true
                                os_log(.info, "Upgraded to HTTP proxy server")
                                if self.buffer.readableBytes > 0 {
                                    os_log(.debug, "[%{public}@] Write: %{public}@", context.remoteAddress!.description, self.buffer.description)
                                    context.pipeline.fireChannelRead(self.wrapInboundOut(self.buffer))
                                    context.pipeline.fireChannelReadComplete()
                                }
                            case .failure(let failure):
                                os_log(.error, "Failed to upgrade to HTTP proxy server: %{public}@", failure.localizedDescription)
                                context.close(promise: nil)
                            }
                        }
                case .failure(let failure):
                    os_log(.error, "Failed to connect to upstream %{public}@:%d@: %{public}@", self.host, self.port, failure.localizedDescription)
                    context.close(promise: nil)
                }
            }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if connected {
            context.fireChannelRead(data)
        } else {
            os_log(.debug, "[%{public}@] Read: %{public}@", context.remoteAddress!.description, data.description)
            var data = unwrapInboundIn(data)
            buffer.writeBuffer(&data)
        }
    }
}

func runMitmServer(url: URL, isRequestAndResponse: Bool, certificate: Data, privateKey: Data, persistenceController: PersistenceController, _ completion: @escaping () -> Void) {
    var sslContext: NIOSSLContext?
    let certificate = try! NIOSSLCertificate(bytes: [UInt8](certificate), format: .der)
    let privateKey = try! NIOSSLPrivateKey(bytes: [UInt8](privateKey), format: .der)
    let configuration = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
    sslContext = try! NIOSSLContext(configuration: configuration)
    // Process packets in the tunnel.
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPSConnectHandler())
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
                    channel.pipeline.addHandler(ProxyHandler(url: url, isRequestAndResponse: isRequestAndResponse, persistenceController: persistenceController))
                }
        }
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .bind(host: "127.0.0.1", port: ProxyServerPort)
        .whenComplete { result in
            switch result {
            case .success:
                NotificationService.notificationSent = false
                os_log(.info, "MitM proxy binded")
                completion()
            case .failure(let failure):
                fatalError("Failed to bind MitM proxy: \(failure.localizedDescription)")
            }
        }
}

func runServer(url: URL, isRequestAndResponse: Bool, persistenceController: PersistenceController, _ completion: @escaping () -> Void) {
    // Process packets in the tunnel.
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(HTTPHandler(url: url))
                .flatMap { _ in
                    channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }
                .flatMap { _ in
                    channel.pipeline.addHandler(ProxyHandler(url: url, isRequestAndResponse: isRequestAndResponse, persistenceController: persistenceController))
                }
        }
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
        .bind(host: "127.0.0.1", port: ProxyServerPort)
        .whenComplete { result in
            switch result {
            case .success:
                NotificationService.notificationSent = false
                os_log(.info, "Proxy binded")
                completion()
            case .failure(let failure):
                fatalError("Failed to bind proxy: \(failure.localizedDescription)")
            }
        }
}
