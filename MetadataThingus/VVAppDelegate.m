//
//  VVAppDelegate.m
//  MetadataThingus
//
//  Created by David Lublin on 12/17/11.
//  Copyright (c) 2011 Vidvox. All rights reserved.
//

#import "VVAppDelegate.h"

@implementation VVAppDelegate

@synthesize window = _window;

- (void)dealloc {
    if (_mdItem) {
        [_mdItem release];
        _mdItem = nil;
    }
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification   {
    // Insert code here to initialize your application
    _mdItem = nil;
}

- (IBAction)pathFieldUsed:(id)sender    {
    NSLog(@"%s",__func__);
    NSString *path = [sender stringValue];
    if (path==nil)
        return;
    NSURL *pathURL = [NSURL URLWithString:[path stringByExpandingTildeInPath]];
    
    if (_mdItem) {
        [_mdItem release];
        _mdItem = nil;
    }
    
    _mdItem = [VVMetadataThingus createWithURL:pathURL];
    if (_mdItem)    {
        [_mdItem retain];
        [self updateUTIField:nil];
    }

}

- (IBAction) updateUTIField:(id)sender  {
    NSLog(@"%s",__func__);
    if (_mdItem==nil)   {
        [utiTextField setStringValue:@"NO URL"];
    }
    //  If the thingus is still loading just activate the spinner
    //  Otherwise get the UTI!
    NSString *prefUTI = [_mdItem valueForAttribute:@"kMDItemContentType"];
    if (prefUTI!=nil)   {
        [utiTextField setStringValue:prefUTI];
    }
    else    {
        [utiTextField setStringValue:@"Unknown UTI"];
    }
    
}

@end
