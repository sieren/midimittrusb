//
//  AudioDeviceController.m
//  Popup
//
//  Created by Matthias Frick on 07.02.2016.
//
//

#import "AudioDeviceController.h"

@interface AudioDeviceController ()

@property (nonatomic, strong) CAInterDeviceAudioViewController* audioDeviceViewController;
@end


@implementation AudioDeviceController
@synthesize adc;
@synthesize audioDeviceViewController;
@synthesize deviceView;

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.deviceView addSubview:self.audioDeviceViewController.view];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(id)init {
  
  adc = [super initWithWindowNibName:@"Devices"];
  self.audioDeviceViewController = [CAInterDeviceAudioViewController new];
  if(adc == nil){
    return nil;
  }
  self = adc;
  return adc;
  
}

@end
