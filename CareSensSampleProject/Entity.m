//
//  Entity.m
//  BLEExample
//
//  Created by isens on 8/17/16.
//  Copyright © 2016 isens. All rights reserved.
//

#import "Entity.h"

@implementation Entity

// Insert code here to add functionality to your managed object subclass
#define entityName @"Entity"

+ (nonnull instancetype)insertEntity:(nonnull NSManagedObjectContext *)context serialNumber:(NSString*)sn seqNumber:(long)seqNumber {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    
    NSError *error = nil;
    NSArray *fetchArray;
    fetchArray = [context executeFetchRequest:fetchRequest error:&error];
    if (!fetchArray) {
        NSLog(@"Error fetc hing Employee objects: %@\n%@", [error localizedDescription], [error userInfo]);
    }
    if ([fetchArray count] <= 0) {
        Entity *entity = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
        entity.serialNumber = sn;
        entity.lastSeqNumber = [NSNumber numberWithLong:seqNumber];
        return entity;
    }
    
    Entity *entity = [[context executeFetchRequest:fetchRequest error:nil]lastObject];
    entity.serialNumber = sn;
    entity.lastSeqNumber = [NSNumber numberWithLong:seqNumber];
    
    NSError *err;
    [context save:&err];
    if (err) {
        NSLog(@"Error saving: %@", err);
    }
    
    return entity;
}

+ (long)selectEntity:(nonnull NSManagedObjectContext *)context serialNumber:(NSString*)sn{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    
    // where 절
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"serialNumber == %@", sn];
    [fetchRequest setPredicate:predicate];

    NSError *error = nil;
    NSArray *fetchArray = [context executeFetchRequest:fetchRequest error:&error];
    if (!fetchArray) {
        NSLog(@"Error fetching Employee objects: %@\n%@", [error localizedDescription], [error userInfo]);
        return 0;
    }
    if ([fetchArray count] <= 0) {
        return 0;
    }
    
    Entity *entity = [fetchArray objectAtIndex:0];
    return [entity.lastSeqNumber longValue];
}

@end
