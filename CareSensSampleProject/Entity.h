//
//  Entity.h
//  BLEExample
//
//  Created by isens on 8/17/16.
//  Copyright © 2016 isens. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Entity : NSManagedObject

// Insert code here to declare functionality of your managed object subclass
+ (nonnull instancetype)insertEntity:(nonnull NSManagedObjectContext *)context serialNumber:(NSString*)sn seqNumber:(long)seqNumber;
+ (long)selectEntity:(nonnull NSManagedObjectContext *)context serialNumber:(NSString*)sn;
//+ (NSManagedObjectContext *)managedObjectContext;
@end

NS_ASSUME_NONNULL_END

#import "Entity+CoreDataProperties.h"
#define LAST_SEQ_NUMBER   @"lastSeqNumber"
#define SERIAL_NUMBER   @"serialNumber"
