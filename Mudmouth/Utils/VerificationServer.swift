import Crypto
import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import X509
import OSLog

class VerificationHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let httpData = unwrapInboundIn(data)
        guard case .head = httpData else {
            return
        }
        let headers = HTTPHeaders([("Content-Length", "0")])
        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

func verifyCertificateTrust(certificate: Certificate, privateKey: P256.Signing.PrivateKey, _ completion: @escaping (_ success: Bool) -> Void) {
    let serializedCertificate = serializeCertificate(certificate)
    let (certificate, privateKey) = generateSiteCertificate(url: "https://127.0.0.1:26386", caCertificateData: serializedCertificate, caPrivateKeyData: privateKey.rawRepresentation)
    var sslContext: NIOSSLContext?
    do {
        let certificate = try NIOSSLCertificate(bytes: certificate, format: .der)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](privateKey), format: .der)
        let configuration = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
        sslContext = try NIOSSLContext(configuration: configuration)
    } catch {
        fatalError("Failed to create TLS context: \(error.localizedDescription)")
    }

    // Run in background thread to avoid performance warning, also see https://github.com/apple/swift-nio/issues/2223.
    DispatchQueue.global(qos: .background).async {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(SOL_SOCKET, SO_REUSEADDR), value: 1)
            .childChannelInitializer({ channel in
                let handler = NIOSSLServerHandler(context: sslContext!)
                return channel.pipeline.addHandler(handler)
                    .flatMap { _ in
                        channel.pipeline.configureHTTPServerPipeline()
                    }
                    .flatMap { _ in
                        channel.pipeline.addHandler(VerificationHandler())
                    }
            })
        // 26836 represents 2-M-U-D-M.
        bootstrap.bind(to: try! SocketAddress(ipAddress: "127.0.0.1", port: 26836)).whenComplete { result in
            switch result {
            case .success:
                os_log(.info, "Verification server binded")
                URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://127.0.0.1:26836")!, timeoutInterval: 1)) { data, response, error in
                    if error != nil {
                        os_log(.error, "Failed to send verification request: %{public}@", error!.localizedDescription)
                    }
                    group.shutdownGracefully { error2 in
                        if error2 != nil {
                            fatalError("Failed to shutdown verification server: \(error2!.localizedDescription)")
                        }
                        completion(error == nil)
                    }
                }
                .resume()
            case .failure(let failure):
                fatalError("Failed to bind verification server: \(failure)")
            }
        }
    }
}
