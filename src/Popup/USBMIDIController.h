//
//  USBMIDIController.h
//  Popup
//
//  Created by Matthias Frick on 30.01.2015.
//
//

#import "PTChannel.h"
#import <Foundation/Foundation.h>
static const NSTimeInterval PTAppReconnectDelay = 1.0;


@interface USBMIDIController : NSObject<NSApplicationDelegate, PTChannelDelegate>
@property (nonatomic, strong, readonly) NSArray *availableDevices;
@property (nonatomic, strong) NSMutableDictionary *lastMIDIPacket;

+(USBMIDIController *)sharedInstance;
-(void)initControllers;
-(void)sendDataToUSB:(const UInt8 *)data size:(UInt32)size;
-(NSDictionary*) connectionStatus;
-(NSDictionary*) lastPacket;
@end
