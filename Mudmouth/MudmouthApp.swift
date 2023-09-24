//
//  MudmouthApp.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import SwiftUI

@main
struct MudmouthApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}