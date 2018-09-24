#import "BackgroundView.h"
#import "StatusItemView.h"
#import "USBMIDIController.h"


@class PanelController;

@protocol PanelControllerDelegate <NSObject>

@optional

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller;

@end

#pragma mark -

@interface PanelController : NSWindowController <NSWindowDelegate>
{
    BOOL _hasActivePanel;
    __unsafe_unretained BackgroundView *_backgroundView;
    __unsafe_unretained id<PanelControllerDelegate> _delegate;
    __unsafe_unretained NSSearchField *_searchField;
    __unsafe_unretained NSTextField *_textField;
    __unsafe_unretained NSButton *quitButton;
}

@property (nonatomic, unsafe_unretained) IBOutlet BackgroundView *backgroundView;
@property (nonatomic, unsafe_unretained) IBOutlet NSSearchField *searchField;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *textField;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *quitButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *deviceName;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *devicePing;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *urlField;
@property (nonatomic, strong) IBOutlet NSButton *preferencesButton;
@property (nonatomic, strong) IBOutlet NSButton *iosAudioButton;
@property (nonatomic, strong) IBOutlet NSButton *blueDeviceButton;
@property (nonatomic, retain) IBOutlet NSView *devView;
@property (nonatomic, retain) IBOutlet NSWindow *devWindow;
@property (nonatomic, retain) IBOutlet NSWindowController *deviceWindow;
@property (nonatomic, unsafe_unretained) IBOutlet NSImageView *modelImage;
@property (nonatomic) BOOL hasActivePanel;
@property (nonatomic, unsafe_unretained, readonly) id<PanelControllerDelegate> delegate;

@property (nonatomic, strong) USBMIDIController *usbMIDIcontroller;

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate;
-(void)updateDeviceStatusWithDictionairy:(id)sender;
- (void)openPanel;
- (void)closePanel;

@end
