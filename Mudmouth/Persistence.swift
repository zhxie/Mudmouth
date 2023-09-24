//
//  Persistence.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
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
        do {
            try viewContext.save()
        } catch {
            fatalError("Failed to save view context: \(error.localizedDescription)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Mudmouth")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
