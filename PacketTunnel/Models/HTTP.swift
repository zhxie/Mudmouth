import Foundation
import NIOCore
import NIOHTTP1

class HTTPRequest {
    var headers: HTTPRequestHead
    var body: Data?

    init(headers: HTTPRequestHead) {
        self.headers = headers
    }

    public func appendBody(_ body: ByteBuffer) {
        if self.body == nil {
            self.body = Data()
        }
        let data = body.getBytes(at: body.readerIndex, length: body.readableBytes)!
        self.body!.append(contentsOf: data)
    }
}

class HTTPResponse {
    var headers: HTTPResponseHead
    var body: Data?

    init(headers: HTTPResponseHead) {
        self.headers = headers
    }

    public func appendBody(_ body: ByteBuffer) {
        if self.body == nil {
            self.body = Data()
        }
        let data = body.getBytes(at: body.readerIndex, length: body.readableBytes)!
        self.body!.append(contentsOf: data)
    }
}
