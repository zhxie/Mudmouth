import CoreData
import NIOHTTP1

extension Record {
    convenience init(context: NSManagedObjectContext, url: String, method: HTTPMethod, requestHeaders: String) {
        self.init(context: context)
        self.url = url
        date = .now
        self.method = method.rawValue
        self.requestHeaders = requestHeaders
    }

    convenience init(context: NSManagedObjectContext, url: String, method: HTTPMethod, requestHeaders: String, status: HTTPResponseStatus, responseHeaders: String) {
        self.init(context: context, url: url, method: method, requestHeaders: requestHeaders)
        self.status = Int16(status.code)
        self.responseHeaders = responseHeaders
    }
}
