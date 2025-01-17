extension PersistenceController {
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let googleProfile = Profile(context: viewContext)
        googleProfile.name = "Google"
        googleProfile.url = "https://www.google.com"
        googleProfile.preAction = Action.urlScheme.rawValue
        googleProfile.preActionUrlScheme = "https://www.google.com"
        let bingProfile = Profile(context: viewContext)
        bingProfile.name = "Bing"
        bingProfile.url = "https://www.bing.com"
        bingProfile.preAction = Action.urlScheme.rawValue
        bingProfile.preActionUrlScheme = "https://www.bing.com"
        let duckDuckGoProfile = Profile(context: viewContext)
        duckDuckGoProfile.name = "DuckDuckGo"
        duckDuckGoProfile.url = "https://www.duckduckgo.com"
        duckDuckGoProfile.preAction = Action.urlScheme.rawValue
        duckDuckGoProfile.preActionUrlScheme = "https://www.duckduckgo.com"
        let googleRecord = Record(context: viewContext)
        googleRecord.date = .now
        googleRecord.url = "https://www.google.com"
        googleRecord.method = "GET"
        googleRecord.requestHeaders = "Connection: keep-alive"
        let bingRecord = Record(context: viewContext)
        bingRecord.date = .now.addingTimeInterval(1)
        bingRecord.url = "https://www.bing.com"
        bingRecord.method = "POST"
        bingRecord.requestHeaders = "Connection: close"
        bingRecord.status = 200
        bingRecord.responseHeaders = "Cache-control: no-cache"
        try! viewContext.save()
        return result
    }()
}
