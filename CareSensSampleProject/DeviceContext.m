//
//  DeviceContext.m
//  BLE Example
//
//  Created by gihoon on 10/15/15.
//  Copyright © 2015 i-SENS. All rights reserved.
//

// BLE Sample Code from
// http://code.tutsplus.com/tutorials/ios-7-sdk-core-bluetooth-practical-lesson--mobile-20741

#import "DeviceContext.h"

// Unit conversion multiplier for glucose values (mg/dL = 18.016 * mmol/L)
static double const GlucoseUnitConversionMultiplier = 18.016;

// Ketone values are stored and transferred multiplied with 10.
// So actual ketone values should be divided by 10.
static double const KetoneMultiplier = 10.0;

@interface DeviceContext () <CBCentralManagerDelegate, CBPeripheralDelegate>
{
    CBUUID *deviceinfo_service;
    CBUUID *glucose_service;
    CBUUID *characteristic_measurement;
    CBUUID *characteristic_context;
    CBUUID *characteristic_racp;
    CBUUID *characteristic_serialnumber;
    CBUUID *characteristic_softwarerevision;
    CBUUID *custom_service;
    CBUUID *characteristic_custom;
    CBUUID *custom_service_v150;
    CBUUID *characteristic_custom_v150;

    CALL_ACTION call_action_type;
    GLUCOSE_RADIO_TAG glucose_unit_tag;
    long sequence_number;
    NSString *time_sync_string;
    
    Boolean is_passkey_success;
    NSTimer *timer_for_passkey_entry;
    
    Boolean is_use_ketone_hilo_flag;
    int revision_minor;
}

//typedef struct {
//    int sequenceNumber;
//    long time;
//    float glucoseData;
//    int flag_cs;
//    int flag_hilow;
//    int flag_context;
//    int flag_meal;
//    int flag_fasting;
//    int flag_ketone;
//    int flag_nomark;
//} Record;

// BLE

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) CBCharacteristic *RecordAccessControlPointCharacteristic;
@property (strong, nonatomic) CBCharacteristic *MesurementCharacteristic;
@property (strong, nonatomic) CBCharacteristic *ContextCharacteristic;
@property (strong, nonatomic) CBCharacteristic *Custom_Characteristic;
@property (strong, nonatomic) CBCharacteristic *Serial_Characteristic;
@property (strong, nonatomic) NSMutableArray *arrayRecord;
@end

static NSString * const GlucoseService = @"1808";
static NSString * const GlucoseMeasurementCharacteristic = @"2A18";
static NSString * const GlucoseContextCharacteristic = @"2A34";
static NSString * const SerialNumberCharacteristic = @"2A25";
static NSString * const SoftwareRevisionCharacteristic = @"2A28";
static NSString * const RACPCharacteristic = @"2A52";
static NSString * const CustomService = @"FFF0"; //custom BLE service
static NSString * const CustomCharacteristic = @"FFF1"; //custom BLE characteristic
static NSString * const CustomServiceV150 = @"C4DEA010-5A9D-11E9-8647-D663BD873D93";
static NSString * const CustomCharacteristicV150 = @"C4DEA3BC-5A9D-11E9-8647-D663BD873D93";

static uint8_t totalCountOperationBytes[] = {0x04, 0x01};
static uint8_t downloadAllOperationBytes[] = {0x01, 0x01};
static uint8_t downloadAfterOperationBytes[] = {0x01, 0x03, 0x01};
static uint8_t downloadAfterOldVerOperationBytes[] = {0x04, 0x03, 0x01};
static uint8_t dataTransferCompleteBytes[] = {0x06, 0x00, 0x01, 0x06}; // no records found
static uint8_t dataTransferCompleteBytes2[] = {0x06, 0x00, 0x01, 0x01}; // send success response
static uint8_t numberOfStoredRecoredsResponseOperationByte = 0x05;
static uint8_t customResponseOperationByte = 0x05;

//
static int supportKetoneHilowRevisionMajor = 1;
static int supportKetoneHilowRevisionMinor = 4;
static int supportNoUseNoRecordsFoundMinor = 5;

@implementation DeviceContext {
    bool isCBCentralManagerStatePoweredOn;
    uint16_t m_sequence;
    NSNumber *m_glucose_ori;
    NSNumber *m_glucose;
    NSString *m_date;
    uint16_t m_timeOffset;
    NSString *m_hilo;
    NSString *m_glucoUnit;
}

@synthesize RecordAccessControlPointCharacteristic;
@synthesize MesurementCharacteristic;
@synthesize ContextCharacteristic;
@synthesize Custom_Characteristic;
@synthesize Serial_Characteristic;

+ (id)sharedInstance {
    static DeviceContext *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self alloc] init] initDeviceContext];
    });
    return instance;
}

- (DeviceContext*)initDeviceContext {
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _arrayRecord = [[NSMutableArray alloc] init];
    isCBCentralManagerStatePoweredOn = false;
    is_passkey_success = false; // isPaired, Passkey Entry Passed

    glucose_service = [CBUUID UUIDWithString:GlucoseService];
    characteristic_measurement = [CBUUID UUIDWithString:GlucoseMeasurementCharacteristic];
    characteristic_context = [CBUUID UUIDWithString:GlucoseContextCharacteristic];
    characteristic_racp = [CBUUID UUIDWithString:RACPCharacteristic];
    characteristic_serialnumber = [CBUUID UUIDWithString:SerialNumberCharacteristic];
    characteristic_softwarerevision =[CBUUID UUIDWithString:SoftwareRevisionCharacteristic];
    custom_service = [CBUUID UUIDWithString:CustomService];
    characteristic_custom = [CBUUID UUIDWithString:CustomCharacteristic];
    custom_service_v150 = [CBUUID UUIDWithString:CustomServiceV150];
    characteristic_custom_v150 = [CBUUID UUIDWithString:CustomCharacteristicV150];

    return self;
}

- (void)startScan {
    if(isCBCentralManagerStatePoweredOn) {
        [_centralManager scanForPeripheralsWithServices: [NSArray arrayWithObjects:[CBUUID UUIDWithString:GlucoseService], nil] options:nil];
        NSLog(@"#01 Bluetooth scan started");
    }
}

- (void)stopScan {
    NSLog(@"#99 Bluetooth scan stopped");
    [_centralManager stopScan];
}

- (void)sendComplete {
    NSLog(@"#60 sendComplete - Writing complete");
    call_action_type = call_with_idle;
    [self.delegate complete];
    //if ( RecordAccessControlPointCharacteristic == NULL ) return;
}

- (void)connectDevice:(CBPeripheral*)peripheral withAction:(CALL_ACTION)action isMgdlUnit:(bool)isGlucoseMgdl{
    NSLog(@"#03 connectDevice to peripheral %@", peripheral);
    call_action_type = action;
    if (isGlucoseMgdl) {
        glucose_unit_tag = RadioButtonTagMgdl;
    } else {
        glucose_unit_tag = RadioButtonTagMmol;
    }
    // NSLog(@"glucose unit1: %d", m_glucoseUnit);
    
    if(peripheral) {
        [_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)setSeqNumber:(long)number {
    sequence_number = number;
}

// BLE
#pragma -
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // You should test all scenarios
    NSLog(@"#00 centralManagerDidUpdateState");
    if (central.state == CBCentralManagerStatePoweredOff) {
        NSLog(@"#00 CBCentralManagerStatePoweredOff");
        isCBCentralManagerStatePoweredOn = false;
    } else if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"#00 CBCentralManagerStatePoweredOn");
        isCBCentralManagerStatePoweredOn = true;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"#02 didDiscoverPeripheral [%@] [RSSI:%d]", peripheral.name, [RSSI intValue]);
    [self.delegate discoveredDevice:peripheral RSSI:RSSI];
    
    if (_discoveredPeripheral != peripheral) {
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        _discoveredPeripheral = peripheral;
        
        // And connect
        //NSLog(@"Connecting to peripheral %@", peripheral);
        //[_centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"#07 didFailToConnectPeripheral: %@", peripheral.name);
    [self cleanup];
}

- (void)cleanup {
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
    call_action_type = call_with_idle;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"#08 didConnectPeripheral: %@", peripheral.name);
    
    [self stopScan];
    NSLog(@"#09 Bluetooth scan stopped");
    
    peripheral.delegate = self;
    self.connectedPeripheral = peripheral;
    is_passkey_success = false;

    if(call_action_type == call_with_idle) {
        NSLog(@"#10 didConnectPeripheral - call discoverServices");
        [peripheral discoverServices:nil];
    } else if(call_action_type == call_with_total_count || call_action_type == call_with_download_all || call_action_type == call_with_download_after || call_action_type == call_with_disconnect) {
        NSLog(@"#11 didConnectPeripheral - call setNotifyValue:forCharacteristic:RecordAccessControlPointCharacteristic");
        [peripheral setNotifyValue:YES forCharacteristic:RecordAccessControlPointCharacteristic];
    } else if(call_action_type == call_with_sync_time) {
        if(Custom_Characteristic) {
            NSLog(@"#12 didConnectPeripheral - call setNotifyValue:forCharacteristic:Custom_Characteristic");
            [peripheral setNotifyValue:YES forCharacteristic:Custom_Characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        NSLog(@"#14 didDiscoverServices - discoverCharacteristics: %@", service);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if([characteristic.UUID isEqual:characteristic_serialnumber]) {
            Serial_Characteristic = characteristic;
        }
        else if([characteristic.UUID isEqual:characteristic_softwarerevision]) {
            NSLog(@"#15 didDiscoverCharacteristicsForService - characteristic_softwarerevision: %@", service);
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if([characteristic.UUID isEqual:characteristic_racp]) {
            RecordAccessControlPointCharacteristic = characteristic;
        }
        else if([characteristic.UUID isEqual:characteristic_measurement]) {
            MesurementCharacteristic = characteristic;
        }
        else if([characteristic.UUID isEqual:characteristic_context]) {
            ContextCharacteristic = characteristic;
        }
        else if([characteristic.UUID isEqual:characteristic_custom] || [characteristic.UUID isEqual:characteristic_custom_v150]) {
            Custom_Characteristic = characteristic;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error");
        return;
    }
  NSLog(@"### didUpdateValueForCharacteristic : %@, UUID: %@, Measurement UUID: %@",characteristic.value,characteristic.UUID, characteristic_measurement);
    
    if (!error) {
        const uint8_t *array = [characteristic.value bytes];
        if ([characteristic.UUID isEqual:characteristic_softwarerevision]) {
            NSString *software_revision = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            NSLog(@"#16 software revision number: %@", software_revision);
            [self.delegate sendDeviceVersion:software_revision];
            NSArray *arr = [software_revision componentsSeparatedByString:@"."];
            if(arr.count < 2) {
                [self.delegate sendDeviceId:@"version error"];
                [self.delegate lowVersion:TRUE];
            }
            int majorRevision = [arr[0] intValue];
            revision_minor = [arr[1] intValue];
            is_use_ketone_hilo_flag = false;
            if (majorRevision >= supportKetoneHilowRevisionMajor) {
                if (revision_minor >= supportKetoneHilowRevisionMinor) {
                    is_use_ketone_hilo_flag = true;
                }
                if (Custom_Characteristic == NULL) {
                   [self.delegate sendDeviceId:@"version error"];
                   [self.delegate lowVersion:TRUE];
                   //return;
                } else {
                   [self.delegate lowVersion:FALSE];
                }
            } else { //if the revision is not 1
                [self.delegate sendDeviceId:@"version error"];
                [self.delegate lowVersion:TRUE];
                //return;
            }
            NSLog(@"#17 didUpdateValueForCharacteristic - Serial_Characteristic");
            [peripheral readValueForCharacteristic:Serial_Characteristic];
        } else if ([characteristic.UUID isEqual:characteristic_serialnumber]) {
            NSString *serial_number = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            NSLog(@"#18 serial number: %@", serial_number);
            [self.delegate sendSerialNumber:serial_number];
        } else if ([characteristic.UUID isEqual:characteristic_custom] || [characteristic.UUID isEqual:characteristic_custom_v150]) {
            if(array[0] == customResponseOperationByte) { // 0x05 time result
                [self.delegate sendTimeSync:time_sync_string];
            }
        } else if ([characteristic.UUID isEqual:characteristic_measurement]) {
            if(call_action_type == call_with_download_all || call_action_type == call_with_download_after) {
                NSLog(@"#52 mesurement value: %@",characteristic.value);
                
                uint16_t offset = 0;
                uint16_t flags = (uint16_t)(array[offset]); //offset:0
                offset += 1;
                
                Boolean timeOffsetPresent = (flags & 0x01) > 0;
                Boolean typeAndLocationPresent = (flags & 0x02) > 0;
                Boolean sensorStatusAnnunciationPresent = (flags & 0x08) > 0;
                Boolean contextInfoFollows = (flags & 0x10) > 0;
                
                uint16_t sequencenumber = (uint16_t)(array[offset+1] << 8) + (uint16_t)array[offset];
                offset += 2;
                
                uint16_t year   = (uint16_t)(array[offset+1] << 8) + (uint16_t)array[offset];
                
                NSString * dateString = [NSString stringWithFormat:@"%d-%d-%d %d:%d:%d", year, array[offset+2], array[offset+3], array[offset+4], array[offset+5], array[offset+6]];
                offset += 7;
                
                
                int16_t timeoffset = 0;
                if (timeOffsetPresent == true) {
                    timeoffset = (int16_t)(array[offset+1] << 8) + (int16_t)array[offset]; //offset: 10
                    offset += 2;
                    
                    // add timeoffset to minutes of time
                    NSDateFormatter *dateformat = [[NSDateFormatter alloc]init];
                    [dateformat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    [dateformat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                    
                    NSLog(@"#53 Original DateTime: %@", dateString);
                    NSDate *dateTime = [dateformat dateFromString:dateString];
                    dateTime = [dateTime dateByAddingTimeInterval:(60 * timeoffset)]; // + minute
                    dateString = [dateformat stringFromDate:dateTime];
                    NSLog(@"#54 Changed DateTime By Offset: %@", dateString);
                }
                
                NSNumber *glucose = 0;
                uint16_t cs = 0;
                NSString *glucose_unit = @"mg/dL";
                if (typeAndLocationPresent == true) {
                    uint16_t glucoseInt = (uint16_t)((array[offset+1] & 0x0F) << 8) + (uint16_t)array[offset];// glucose unit (always mg/dL) //offset: 10 or 12
                    glucose = [NSNumber numberWithInteger:glucoseInt];
                    m_glucose_ori = glucose;
                    NSLog(@"#55 glucose unit2: %@", glucose_unit_tag == RadioButtonTagMgdl ? @"mg/dL" : @"mmol/L");
                    if(glucose_unit_tag == RadioButtonTagMmol) {
                        glucose_unit = @"mmol/L";
                        float glucoseFloat = roundf(glucoseInt/GlucoseUnitConversionMultiplier * 10) / 10;
                        glucose = [NSNumber numberWithFloat:glucoseFloat];
                    }
                    
                    cs = (uint16_t)((array[offset+2] & 0xF0) >> 4);	// Control Solution
                    offset += 3;
                }
                
                uint16_t hi_lo = 0;
                if (sensorStatusAnnunciationPresent == true) {
                    hi_lo = (uint16_t)(array[offset+1] << 8) + (uint16_t)array[offset]; //offset: 14 or 16
                }
                
                NSString *hilo = @"-";
                if(hi_lo == 64){
                    hilo = @"Lo";
                }
                else if(hi_lo == 32) {
                    hilo = @"Hi";
                }
                
                if (contextInfoFollows == false) {
                    //complete - not context data
                }
                
                m_sequence = sequencenumber;
                m_glucose = glucose;
                m_date = dateString;
                m_timeOffset = timeoffset;
                m_hilo = hilo;
                m_glucoUnit = glucose_unit;
                
                NSString *resultString = [NSString stringWithFormat:@"#56 measurement sequence: %d, glucose: %@ %@, date: %@, timeoffset: %d,  hilo: %@", sequencenumber, glucose, glucose_unit, dateString, timeoffset, hilo];
                [self.delegate sendSequenceNo:sequencenumber];
                [self.delegate sendGlucose:resultString];
            }
        } else if ([characteristic.UUID isEqual:characteristic_context]) {
            // TODO : collect data by sequence number
//          NSValue * value = [_arrayRecord lastObject];
//          [value getValue:&_arrayRecord];
//          NSLog(@" Context Value: %@", value);
            
            uint16_t sequencenumber = (uint16_t)(array[2] << 8) + (uint16_t)array[1];
            // meal array[0) == 10 flag true
            // if (meal == 10) is true means meal flag is set.
            // ### context meal-flag: 00	nomark
            // ### context meal-flag: 11	fasting
            // ### context meal-flag: 10	after meal
            // ### context meal-flag: 01	before meal
            // ### context meal-flag: 110	ketone
            
            NSLog(@"#57 context sequence: %d, isMealFlagSet: %d, meal-flag: %d", sequencenumber, array[0], array[3]);
            bool isMealFlagSet = (array[0] == 2);
            if(isMealFlagSet) {
                NSString *mealFlagString = @"unknown";
                switch(array[03]) {
                    case 0: // 00
                        mealFlagString = @"nomark";
                        break;
                    case 1: // 01
                        mealFlagString = @"before meal";
                        break;
                    case 2: // 10
                        mealFlagString = @"after meal";
                        break;
                    case 3: // 11
                        mealFlagString = @"fasting";
                        break;
                    case 6: // 110
                        mealFlagString = @"ketone";
                        break;
                    default:
                        break;
                }
                
                NSString *resultString = @"";
                if([mealFlagString isEqual:@"ketone"]) {
                    float glucoseValue = [m_glucose_ori floatValue];
                    float ketoneValue = glucoseValue / KetoneMultiplier;
                    NSNumber *ketone = [NSNumber numberWithFloat:ketoneValue];
                    if (is_use_ketone_hilo_flag == false) {
                        m_hilo = @"";
                    }
                    resultString = [NSString stringWithFormat:@"#58 context sequence: %d, ketone: %@ mmol/L, date: %@, timeoffset: %d, hilo: %@ ", m_sequence, ketone, m_date, m_timeOffset, m_hilo];
                } else {
                    resultString = [NSString stringWithFormat:@"#59 context sequence: %d, glucose: %@ %@, date: %@, timeoffset: %d, hilo: %@ ", m_sequence, m_glucose, m_glucoUnit, m_date, m_timeOffset, m_hilo];
                }
                
                [self.delegate sendMealFlag:resultString];
            }
        } else if ([characteristic.UUID isEqual:characteristic_racp]) {
            // should be paired with RACP request
            is_passkey_success = true;

            NSData* completeOPCode = [NSData dataWithBytes:&dataTransferCompleteBytes length:sizeof(dataTransferCompleteBytes)];
            NSData* completeOPCode2 = [NSData dataWithBytes:&dataTransferCompleteBytes2 length:sizeof(dataTransferCompleteBytes2)]; // v1.5
            int offset = 0;
            uint8_t opCode = array[offset];
            offset += 2;
            
            if([characteristic.value isEqualToData:completeOPCode] ) {
                NSLog(@"#60 Complete");
                [self sendComplete];
            } else if([characteristic.value isEqualToData:completeOPCode2] && revision_minor >= supportNoUseNoRecordsFoundMinor) {
                NSLog(@"#60 Complete2");
                [self sendComplete];
            } else if(opCode == numberOfStoredRecoredsResponseOperationByte) { //05
                uint16_t totalCountOfData = (uint16_t)(array[offset+1] << 8) + (uint16_t)array[offset];
                NSLog(@"#42 Received total count: %d", totalCountOfData);
                [self.delegate sendTotalCount:totalCountOfData];
            }
        }
    } else {
        NSLog(@"error value");
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    //NSLog(@"$$ characteristic.UUID %@", characteristic.UUID );
    if (characteristic.isNotifying) {
        NSLog(@"#xx Notifying on %@", characteristic);
    } else {
        // Notification has stopped
        [_centralManager cancelPeripheralConnection:peripheral];
    }
    
    if([characteristic.UUID isEqual:characteristic_racp]) {
        if(Custom_Characteristic == NULL) {
            [self.delegate lowVersion:TRUE];
        } else {
            [peripheral setNotifyValue:YES forCharacteristic:MesurementCharacteristic];
        }
    } else if([characteristic.UUID isEqual:characteristic_measurement]) {
        [peripheral setNotifyValue:YES forCharacteristic:ContextCharacteristic];
    } else if([characteristic.UUID isEqual:characteristic_custom] || [characteristic.UUID isEqual:characteristic_custom_v150]) {
        if(call_action_type == call_with_sync_time) {
            NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate date]];
            NSInteger year1 = [components year] & 0xff;
            NSInteger year2 = ([components year] >> 8) & 0xff;
            
            uint8_t buffer[] = {0xc0, 0x03, 0x01, 0x00, year1, year2, [components month], [components day], [components hour], [components minute], [components second]};
            
            NSData* data = [NSData dataWithBytes:&buffer length:sizeof(buffer)];
            NSLog(@"#81 Request time sync: %@", data);
            
            time_sync_string = [NSString stringWithFormat:@"%ld-%ld-%ld %ld:%ld:%ld", [components year], [components month], [components day], [components hour], [components minute],(long)[components second]];
            [peripheral writeValue:data forCharacteristic:Custom_Characteristic type:CBCharacteristicWriteWithResponse];
        }
    } else if([characteristic.UUID isEqual:characteristic_context]) {
        if(call_action_type == call_with_total_count) {
            NSData* data = [NSData dataWithBytes:&totalCountOperationBytes length:2];
            NSLog(@"#41 Request(first call) call_with_total_count: %@", data);
            [self.connectedPeripheral writeValue:data forCharacteristic:RecordAccessControlPointCharacteristic type:CBCharacteristicWriteWithResponse];
            
            // first call
            timer_for_passkey_entry = [NSTimer scheduledTimerWithTimeInterval:2.0f
                                                             target:self
                                                           selector:@selector(timerFired:)
                                                           userInfo:nil
                                                            repeats:NO];
        } else if(call_action_type == call_with_download_all) {
            NSData* data = [NSData dataWithBytes:&downloadAllOperationBytes length:2];
            NSLog(@"#51 Request call_with_download_all: %@", data);
            [peripheral writeValue:data forCharacteristic:RecordAccessControlPointCharacteristic type:CBCharacteristicWriteWithResponse];
        } else if(call_action_type == call_with_download_after) {
            NSMutableData* data = [[NSMutableData alloc]init];
            NSLog(@"#61 Request call_with_download_after: %@", data);
            if(characteristic_serialnumber) {
                data = [NSMutableData dataWithBytes:&downloadAfterOperationBytes length:3];
            } else { //old version
                data = [NSMutableData dataWithBytes:&downloadAfterOldVerOperationBytes length:3];
            }
            NSMutableData* seqNumData = [NSMutableData dataWithBytes:&sequence_number length:2];
            [data appendData:seqNumData];
            NSLog(@"Request after data: %@", data);
            [peripheral writeValue:data forCharacteristic:RecordAccessControlPointCharacteristic type:CBCharacteristicWriteWithResponse];
        } else if (call_action_type == call_with_disconnect) {
            NSData* data = [NSData dataWithBytes:&dataTransferCompleteBytes length:sizeof(dataTransferCompleteBytes)];
            if(revision_minor >= supportNoUseNoRecordsFoundMinor) {
                data = [NSData dataWithBytes:&dataTransferCompleteBytes2 length:sizeof(dataTransferCompleteBytes2)];
            }
            NSLog(@"Request disconnect : %@", data);
            [peripheral writeValue:data forCharacteristic:RecordAccessControlPointCharacteristic type:CBCharacteristicWriteWithResponse];
            [self.delegate disconnect];
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"error in writing characteristic %@ and error %@",characteristic.UUID,[error localizedDescription]);
    } else {
        NSLog(@"#89 didWriteValueForCharacteristic %@ and value %d",characteristic.UUID,characteristic.isNotifying);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"#98 didDisconnectPeripheral: Disconnect");
    _discoveredPeripheral = nil;
    
    [self.delegate disconnect];
    self.connectedPeripheral = nil;
    is_passkey_success = false;

    [self startScan];
}

- (void)timerFired:(NSTimer *)timer {
    if(is_passkey_success == false && self.connectedPeripheral != nil) {
        NSData* data = [NSData dataWithBytes:&totalCountOperationBytes length:2];
        NSLog(@"#41 Request(once more) call_with_total_count: %@", data);
        [self.connectedPeripheral writeValue:data forCharacteristic:RecordAccessControlPointCharacteristic type:CBCharacteristicWriteWithResponse];
    }
    // clear timer
    if (timer_for_passkey_entry != nil && [timer_for_passkey_entry isValid]) {
        [timer_for_passkey_entry invalidate];
        timer_for_passkey_entry = nil;
    }
}





@end
