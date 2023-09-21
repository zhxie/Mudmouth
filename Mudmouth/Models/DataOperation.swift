//
//  DataOperation.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/21.
//  Referenced from https://github.com/genebogdanovich/ChildContextsForEditing.
//

import Foundation
import CoreData

class DataOperation<Object: NSManagedObject>: Identifiable {
    let id = UUID()
    let context: NSManagedObjectContext
    let object: Object
    
    init(context: NSManagedObjectContext, object: Object) {
        self.context = context
        self.object = object
    }
}

class CreateOperation<Object: NSManagedObject>: DataOperation<Object> {
    init(with parentContext: NSManagedObjectContext) {
        let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        childContext.parent = parentContext
        let childObject = Object(context: childContext)
        
        super.init(context: childContext, object: childObject)
    }
}

class UpdateOperation<Object: NSManagedObject>: DataOperation<Object> {
    init(
        withExistingObject object: Object,
        in parentContext: NSManagedObjectContext
    ) {
        let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        childContext.parent = parentContext
        let childObject = childContext.object(with: object.objectID) as! Object
        
        super.init(context: childContext, object: childObject)
    }
}
