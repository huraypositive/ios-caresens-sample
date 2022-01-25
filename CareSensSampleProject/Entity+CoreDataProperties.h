//
//  Entity+CoreDataProperties.h
//  BLEExample
//
//  Created by isens on 8/18/16.
//  Copyright © 2016 isens. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Entity.h"

NS_ASSUME_NONNULL_BEGIN

@interface Entity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *lastSeqNumber;
@property (nullable, nonatomic, retain) NSString *serialNumber;

@end

NS_ASSUME_NONNULL_END
