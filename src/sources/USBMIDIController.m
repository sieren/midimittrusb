//
//  USBMIDIController.m
//  Popup
//
//  Created by Matthias Frick on 30.01.2015.
//
//

#import "USBMIDIController.h"

#import "PTUSBHub.h"
#import "PTExampleProtocol.h"
#import <QuartzCore/QuartzCore.h>
#include <mach/mach_time.h>
// #import "MIKMIDI.h"

id thisUSBCtrlClass;
@interface USBMIDIController() {
    
    // If the remote connection is over USB transport...
    NSNumber *connectingToDeviceID_;
    NSNumber *connectedDeviceID_;
    NSDictionary *connectedDeviceProperties_;
    
    dispatch_queue_t notConnectedQueue_;
    BOOL notConnectedQueueSuspended_;
    PTChannel *connectedChannel_;
    NSDictionary *consoleTextAttributes_;
    NSDictionary *consoleStatusTextAttributes_;
    NSMutableDictionary *pings_;
    
    MIDIClientRef   theMidiClient;
    MIDIEndpointRef midiOut;
    MIDIEndpointRef midiIn;
    MIDIPortRef     outPort;
    MIDIPortRef     inPort;

}

@property (readonly) NSNumber *connectedDeviceID;
@property PTChannel *connectedChannel;
@property (nonatomic, strong)  NSMutableDictionary *remoteDeviceInfo_;


- (void)startListeningForDevices;
- (void)didDisconnectFromDevice:(NSNumber*)deviceID;
- (void)disconnectFromCurrentChannel;
- (void)enqueueConnectToLocalIPv4Port;
- (void)connectToLocalIPv4Port;
- (void)connectToUSBDevice;
- (void)ping;

@end
@implementation USBMIDIController
@synthesize connectedDeviceID = connectedDeviceID_;
@synthesize remoteDeviceInfo_;
@synthesize lastMIDIPacket;


// Singleton
// We are using the singleton-pattern for this, data needs to be fetched only once
// and is stored in this class.
+ (USBMIDIController *)sharedInstance {
    static dispatch_once_t pred;
    static USBMIDIController *sharedProgram = nil;
    dispatch_once(&pred, ^
                  {
                      sharedProgram = [[self alloc] init];
                      
                  });
    return sharedProgram;
}


- (id)init
{
    self = [super init];
    if (self != nil)
    {

    }
    
    return self;
}

-(NSDictionary *) lastPacket {
    return self.lastMIDIPacket;
}

-(void) initControllers {
    
    // We use a serial queue that we toggle depending on if we are connected or
    // not. When we are not connected to a peer, the queue is running to handle
    // "connect" tries. When we are connected to a peer, the queue is suspended
    // thus no longer trying to connect.
    notConnectedQueue_ = dispatch_queue_create("PTExample.notConnectedQueue", DISPATCH_QUEUE_SERIAL);
    
    // Configure the output NSTextView we use for UI feedback
    //  outputTextView_.textContainerInset = NSMakeSize(15.0, 10.0);
    consoleTextAttributes_ = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSFont fontWithName:@"helvetica" size:16.0], NSFontAttributeName,
                              [NSColor lightGrayColor], NSForegroundColorAttributeName,
                              nil];
    consoleStatusTextAttributes_ = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont fontWithName:@"menlo" size:11.0], NSFontAttributeName,
                                    [NSColor darkGrayColor], NSForegroundColorAttributeName,
                                    nil];
    
    // Start listening for device attached/detached notifications
    [self startListeningForDevices];
    
    // Start trying to connect to local IPv4 port (defined in PTExampleProtocol.h)
    [self enqueueConnectToLocalIPv4Port];
    
    // Start pinging
    [self ping];
    
    thisUSBCtrlClass = self;
    
    MIDIClientCreate(CFSTR("midiLE"), NULL, NULL,
                     &theMidiClient);
    MIDISourceCreate(theMidiClient, CFSTR("midiLE USB Source"),
                     &midiOut);
    MIDIDestinationCreate(theMidiClient, CFSTR("midiLE USB Dest"), ReadProc,  (__bridge void *)self, &midiIn);
    
}

-(NSDictionary *)connectionStatus {
    NSLog(@"%@", [self.remoteDeviceInfo_ description]);
    return self.remoteDeviceInfo_;
}


- (PTChannel*)connectedChannel {
    return connectedChannel_;
}

- (void)setConnectedChannel:(PTChannel*)connectedChannel {
    connectedChannel_ = connectedChannel;
    
    // Toggle the notConnectedQueue_ depending on if we are connected or not
    if (!connectedChannel_ && notConnectedQueueSuspended_) {
        dispatch_resume(notConnectedQueue_);
        notConnectedQueueSuspended_ = NO;
    } else if (connectedChannel_ && !notConnectedQueueSuspended_) {
        dispatch_suspend(notConnectedQueue_);
        notConnectedQueueSuspended_ = YES;
    }
    
    if (!connectedChannel_ && connectingToDeviceID_) {
        [self enqueueConnectToUSBDevice];
    }
}


#pragma mark - Ping

- (void)pongWithTag:(uint32_t)tagno error:(NSError*)error {
    NSNumber *tag = [NSNumber numberWithUnsignedInt:tagno];
    NSMutableDictionary *pingInfo = [pings_ objectForKey:tag];
    if (pingInfo) {
        NSDate *now = [NSDate date];
        [pingInfo setObject:now forKey:@"date ended"];
        [pings_ removeObjectForKey:tag];
        [self.remoteDeviceInfo_ setObject:[NSString stringWithFormat:@"%.3f ms", [now timeIntervalSinceDate:[pingInfo objectForKey:@"date created"]]*1000.0] forKey:@"ping"];
      
        
    }
}


- (void)ping {
    if (connectedChannel_) {
        if (!pings_) {
            pings_ = [NSMutableDictionary dictionary];
        }
        uint32_t tagno = [connectedChannel_.protocol newTag];
        NSNumber *tag = [NSNumber numberWithUnsignedInt:tagno];
        NSMutableDictionary *pingInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSDate date], @"date created", nil];
        [pings_ setObject:pingInfo forKey:tag];
        [connectedChannel_ sendFrameOfType:PTExampleFrameTypePing tag:tagno withPayload:nil callback:^(NSError *error) {
            [self performSelector:@selector(ping) withObject:nil afterDelay:1.0];
            [pingInfo setObject:[NSDate date] forKey:@"date sent"];
            if (error) {
                [pings_ removeObjectForKey:tag];
            }
        }];
    } else {
        [self performSelector:@selector(ping) withObject:nil afterDelay:1.0];
    }
}

#pragma mark - Notifications
-(void)sendNotificationWithTitle:(NSString*)title andMessage:(NSString*)message {
    if (NSClassFromString(@"NSUserNotification")) {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

#pragma mark - PTChannelDelegate


- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (   type != PTExampleFrameTypeDeviceInfo
        && type != PTExampleFrameTypeTextMessage
        && type != PTExampleFrameTypePing
        && type != PTExampleFrameTypePong
        && type != PTFrameTypeEndOfStream) {
        NSLog(@"Unexpected frame of type %u", type);
        [channel close];
        return NO;
    } else {
        return YES;
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData*)payload {
    //NSLog(@"received %@, %u, %u, %@", channel, type, tag, payload);
    if (type == PTExampleFrameTypeDeviceInfo) {
        NSDictionary *deviceInfo = [NSDictionary dictionaryWithContentsOfDispatchData:payload.dispatchData];
        self.remoteDeviceInfo_ = [deviceInfo mutableCopy];
        [self sendNotificationWithTitle:@"Connected" andMessage:[NSString stringWithFormat:@"Connected to %@: %@", [remoteDeviceInfo_ objectForKey:@"localizedModel"], [remoteDeviceInfo_ objectForKey:@"name"]]];
    } else if (type == PTExampleFrameTypeTextMessage) {
        PTExampleTextFrame *textFrame = (PTExampleTextFrame*)payload.data;
        textFrame->length = ntohl(textFrame->length);
        uint8 *text = textFrame->utf8text;
        struct MIDIPacket packet;
        packet.timeStamp = mach_absolute_time();
        packet.length = textFrame->length;
        
        
        for (int i= 0; i<textFrame->length; i++) {
            packet.data[i] = text[i];
        }
        [self sendMidiMessage:&packet];
        
        
        
    } else if (type == PTExampleFrameTypePong) {
        [self pongWithTag:tag error:nil];
    }
}

-(void)sendMidiMessage:(MIDIPacket *) packet {
    
    
    char pktBuffer[1024];
    MIDIPacketList* pktList = (MIDIPacketList*) pktBuffer;
    MIDIPacket     *pkt;
    
    pkt = MIDIPacketListInit(pktList);
    
    packet->timeStamp = mach_absolute_time();
    pkt = MIDIPacketListAdd(pktList, 1024, pkt, 0, packet->length, packet->data);
    pkt->timeStamp = mach_absolute_time();
    
    if (pkt == NULL || MIDIReceived(midiOut, pktList)) {
        printf("failed to send the midi.\n");
    }
    
}

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if (connectedDeviceID_ && [connectedDeviceID_ isEqualToNumber:channel.userInfo]) {
        [self didDisconnectFromDevice:connectedDeviceID_];
[self sendNotificationWithTitle:@"Disconnected" andMessage:[NSString stringWithFormat:@"Disconnected from %@: %@", [remoteDeviceInfo_ objectForKey:@"localizedModel"], [remoteDeviceInfo_ objectForKey:@"name"]]];
        self.remoteDeviceInfo_ = nil;
    }
    
    if (connectedChannel_ == channel) {
        
        self.connectedChannel = nil;
        self.remoteDeviceInfo_ = nil;
    }
}


#pragma mark - Wired device connections


- (void)startListeningForDevices {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserverForName:PTUSBDeviceDidAttachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
        NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
        //NSLog(@"PTUSBDeviceDidAttachNotification: %@", note.userInfo);
        NSLog(@"PTUSBDeviceDidAttachNotification: %@", deviceID);
        
        dispatch_async(notConnectedQueue_, ^{
            if (!connectingToDeviceID_ || ![deviceID isEqualToNumber:connectingToDeviceID_]) {
                [self disconnectFromCurrentChannel];
                connectingToDeviceID_ = deviceID;
                connectedDeviceProperties_ = [note.userInfo objectForKey:@"Properties"];
                [self enqueueConnectToUSBDevice];
            }
        });
    }];
    
    [nc addObserverForName:PTUSBDeviceDidDetachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
        NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
        NSLog(@"PTUSBDeviceDidDetachNotification: %@", deviceID);
        
        if ([connectingToDeviceID_ isEqualToNumber:deviceID]) {
            connectedDeviceProperties_ = nil;
            connectingToDeviceID_ = nil;
            if (connectedChannel_) {
                [connectedChannel_ close];
            }
        }
    }];
}


- (void)didDisconnectFromDevice:(NSNumber*)deviceID {
    NSLog(@"Disconnected from device");
    if ([connectedDeviceID_ isEqualToNumber:deviceID]) {
        [self willChangeValueForKey:@"connectedDeviceID"];
        connectedDeviceID_ = nil;
        [self didChangeValueForKey:@"connectedDeviceID"];
    }
}


- (void)disconnectFromCurrentChannel {
    if (connectedDeviceID_ && connectedChannel_) {
        [connectedChannel_ close];
        self.connectedChannel = nil;
    }
}


- (void)enqueueConnectToLocalIPv4Port {
    dispatch_async(notConnectedQueue_, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self connectToLocalIPv4Port];
        });
    });
}



- (void)connectToLocalIPv4Port {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    channel.userInfo = [NSString stringWithFormat:@"127.0.0.1:%d", PTExampleProtocolIPv4PortNumber];
    [channel connectToPort:PTExampleProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error, PTAddress *address) {
        if (error) {
            if (error.domain == NSPOSIXErrorDomain && (error.code == ECONNREFUSED || error.code == ETIMEDOUT)) {
                // this is an expected state
            } else {
                NSLog(@"Failed to connect to 127.0.0.1:%d: %@", PTExampleProtocolIPv4PortNumber, error);
            }
        } else {
            [self disconnectFromCurrentChannel];
            self.connectedChannel = channel;
            channel.userInfo = address;

            NSLog(@"Connected to %@", address);
        }
        [self performSelector:@selector(enqueueConnectToLocalIPv4Port) withObject:nil afterDelay:PTAppReconnectDelay];
    }];
}


- (void)enqueueConnectToUSBDevice {
    dispatch_async(notConnectedQueue_, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self connectToUSBDevice];
        });
    });
}


- (void)connectToUSBDevice {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    channel.userInfo = connectingToDeviceID_;
    channel.delegate = self;
    
    [channel connectToPort:PTExampleProtocolIPv4PortNumber overUSBHub:PTUSBHub.sharedHub deviceID:connectingToDeviceID_ callback:^(NSError *error) {
        if (error) {
            if (error.domain == PTUSBHubErrorDomain && error.code == PTUSBHubErrorConnectionRefused) {
                NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
            } else {
                NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
            }
            if (channel.userInfo == connectingToDeviceID_) {
                [self performSelector:@selector(enqueueConnectToUSBDevice) withObject:nil afterDelay:PTAppReconnectDelay];
            }
        } else {
            connectedDeviceID_ = connectingToDeviceID_;
            self.connectedChannel = channel;
        }
    }];
}



#pragma mark - MIDI

+ (NSSet *)keyPathsForValuesAffectingAvailableDevices
{
    return [NSSet setWithObject:@"midiDeviceManager.availableDevices"];
}

-(void)sendDataToUSB:(const UInt8 *)data size:(UInt32)size {
    
    if (connectedChannel_) {
        dispatch_data_t payload = PTExampleTextDispatchDataWithBytes(data, size);
        [connectedChannel_ sendFrameOfType:PTExampleFrameTypeTextMessage tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
          // NSLog(@"Sent MIDI through USB");
            if (error) {
                NSLog(@"Failed to send message: %@", error);
            }
        }];

    } else {
        NSLog(@"No Peer Found");
    }
    
}


/*
 INCOMING MIDI DATA
 */
void ReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    
    
    MIDIPacket *packet = (MIDIPacket*)packetList->packet;

    
    int j;
    int count = packetList->numPackets;
    for (j=0; j<count; j++) {
      //  NSLog(@"Length: %i, first byte: %x, second byte: %x", packet->length, packet->data[0],packet->data[1]);
        [thisUSBCtrlClass sendDataToUSB:packet->data size:packet->length];
        packet = MIDIPacketNext(packet);
    }

}



@end
