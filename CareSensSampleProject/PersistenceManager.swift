//
//  PersistenceManager.swift
//  CareSensSampleProject
//
//  Created by 장근형 on 2022/01/20.
//

import Foundation

class PersistenceManager {
    static var shared:PersistenceManager = PersistenceManager()
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CareSensCoreData")
        container.loadPersistentStores(completionHandler: {
            (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var context:NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func insertEntity(_ context:NSManagedObjectContext, _ serialNumber:String, _ seqNumber:Int){
        Entity.insertEntity(context, serialNumber: serialNumber, seqNumber: seqNumber)
    }
    
    func selectEntity(_ context:NSManagedObjectContext,_ serialNumber:String) -> Int{
        return Entity.selectEntity(context, serialNumber: serialNumber)
    }
}


