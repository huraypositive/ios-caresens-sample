//
//  DeviceContext.h
//
//  Created by isens on 10/15/15.
//  Copyright © 2016 i-SENS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
@import CoreBluetooth;

typedef enum {
    call_with_idle = 0,
    call_with_total_count,
    call_with_download_all,
    call_with_download_after,
    call_with_sync_time,
    call_with_disconnect
} CALL_ACTION ;

typedef enum {
    RadioButtonTagMgdl,
    RadioButtonTagMmol
} GLUCOSE_RADIO_TAG;

@protocol DeviceContextDelegate <NSObject>
- (void)lowVersion:(bool)isLowVer;
- (void)discoveredDevice:(CBPeripheral*)devicename RSSI:(NSNumber *)RSSI;
- (void)bondedDevice:(CBPeripheral*)devicename;

- (void)sendDeviceId:(NSString*)deviceid;
- (void)sendDeviceVersion:(NSString*)deviceVersion;
- (void)sendSerialNumber:(NSString*)deviceSN;
- (void)sendSequenceNo:(long)sequenceno;
- (void)sendTotalCount:(uint16_t)totalCountOfData;
- (void)sendGlucose:(NSString*)resultString;
- (void)sendMealFlag:(NSString*)resultString;
- (void)sendTimeSync:(NSString*)resultString;
- (void)complete;
- (void)disconnect;
- (void)connectToDevice:(CALL_ACTION)command;
@end

@interface DeviceContext : NSObject

@property (nonatomic, weak) id<DeviceContextDelegate> delegate;

+ (id)sharedInstance;
- (NSManagedObjectContext *)managedObjectContext;
- (DeviceContext*)initDeviceContext;
- (void)startScan;
- (void)stopScan;
- (void)sendComplete;
- (void)setSeqNumber:(long)number;
- (void)connectDevice:(CBPeripheral*)peripheral withAction:(CALL_ACTION)action isMgdlUnit:(bool)isGlucoseMgdl;

- (void)timerFired:(NSTimer *)timer;
@end
