//
//  PreferenceController.m
//  
//
//  Created by Matthias Frick on 01.02.2015.
//
//

#import "PreferenceController.h"
#import <Sparkle/Sparkle.h>
#import "LaunchAtLoginController.h"

@interface PreferenceController () {
   }
@property (nonatomic, strong) IBOutlet NSTextField *curVersion;
@property (nonatomic, strong) IBOutlet NSButton *checkUpdateBtn;
@property (nonatomic, strong) IBOutlet NSButton *launchLoginBtn;
@end

@implementation PreferenceController
@synthesize wc;
@synthesize curVersion;
@synthesize checkUpdateBtn;
@synthesize  launchLoginBtn;
- (void)windowDidLoad {
    [super windowDidLoad];
   
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
-(id)init {

    wc = [super initWithWindowNibName:@"Preferences"];
    if(wc == nil){
        return nil;
    }
    self = wc;
    return wc;
    
}
-(void)showWindow:(id)sender {
    [super showWindow:sender];
    [NSApp activateIgnoringOtherApps:YES];
    [[self window] makeKeyAndOrderFront:nil];
}
-(IBAction)checkUpdatesBox:(id)sender {
    NSButton *btn = (NSButton*)sender;
    if ([btn state] == NSOnState) {
        [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:YES];
    }
    else {
        [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:NO];
    }
    
}
-(IBAction)launchAtLogin:(id)sender {
    NSButton *btn = (NSButton *)sender;
    if ([btn state] == NSOnState) {
        LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
        [launchController setLaunchAtLogin:YES];
    }
    else {
        LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
        [launchController setLaunchAtLogin:NO];
    }
    
}

-(IBAction)checkNow:(id)sender {
    [[SUUpdater sharedUpdater]checkForUpdates:sender];
}
-(IBAction)okButtonPressed:(id)sender {
    [self close];
}

-(void)setLaunchButton {
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    BOOL launch = [launchController launchAtLogin];
    
    if (launch) {
        [self.launchLoginBtn setState:NSOnState];
    }
    else {
        [self.launchLoginBtn setState:NSOffState];
    }
}


-(void)awakeFromNib {
    [super awakeFromNib];
    if ([[SUUpdater sharedUpdater] automaticallyChecksForUpdates] == YES)
    {
        [self.checkUpdateBtn setState: NSOnState];
    }
    else
    {
       [self.checkUpdateBtn setState: NSOffState];
    }
    
    [self setLaunchButton];
    self.curVersion.stringValue = [NSString stringWithFormat:@"Version %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    [NSApp activateIgnoringOtherApps:YES];
    [[self window] makeKeyAndOrderFront:nil];
}

@end
