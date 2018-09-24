//
//  NSAttributedString+Link.h
//  Popup
//
//  Created by Matthias Frick on 30.01.2015.
//
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;
@end
