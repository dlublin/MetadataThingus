//
//  VVAppDelegate.h
//  MetadataThingus
//
//  Created by David Lublin on 12/17/11.
//  Copyright (c) 2011 Vidvox. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VVMetadataThingus.h"

@interface VVAppDelegate : NSObject <NSApplicationDelegate> {
    VVMetadataThingus *_mdItem;
    
    IBOutlet NSTextField *pathTextField;
    IBOutlet NSTextField *utiTextField;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)pathFieldUsed:(id)sender;
- (IBAction) updateUTIField:(id)sender;

@end
