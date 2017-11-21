//
//  Photo+CoreDataClass.swift
//  Virtual Tourist
//
//  Created by James Dellinger on 11/19/17.
//  Copyright © 2017 James Dellinger. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {
    
    convenience init(imageData: NSData, context: NSManagedObjectContext) {
        if let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: entity, insertInto: context)
            self.imageData = imageData
        } else {
            fatalError("Unable to find entity name!")
        }
    }
}
