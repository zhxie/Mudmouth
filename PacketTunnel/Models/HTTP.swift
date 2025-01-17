import Foundation
import NIOCore
import NIOHTTP1

class HTTPRequest {
    var head: HTTPRequestHead
    var body: Data?

    init(head: HTTPRequestHead) {
        self.head = head
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
    var head: HTTPResponseHead
    var body: Data?

    init(head: HTTPResponseHead) {
        self.head = head
    }

    public func appendBody(_ body: ByteBuffer) {
        if self.body == nil {
            self.body = Data()
        }
        let data = body.getBytes(at: body.readerIndex, length: body.readableBytes)!
        self.body!.append(contentsOf: data)
    }
}
