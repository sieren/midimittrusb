//
//  AudioDeviceController.h
//  Popup
//
//  Created by Matthias Frick on 07.02.2016.
//
//

#import <Cocoa/Cocoa.h>
#import "CoreAudioKit/CoreAudioKit.h"

@interface AudioDeviceController : NSWindowController <NSWindowDelegate>

@property (strong) AudioDeviceController *adc;
@property (nonatomic, strong) IBOutlet NSView *deviceView;
@end
