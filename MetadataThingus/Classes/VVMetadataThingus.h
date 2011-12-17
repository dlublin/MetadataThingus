//
//  VVMetadataThingus.h
//  MetadataThingus
//
//  Created by David Lublin on 12/17/11.
//  Copyright (c) 2011 Vidvox. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 This object is designed to function the same as NSMetadataItem
 
 The main difference is that this can be created manually from a path or URL
 Instead of having to rely on NSMetadataQuery to return results
 
 Also, there is a fallback method for situations where the MDItemRef can not be created
 eg. Drive is not yet indexed or folder is ignored by spotlight or URL is not a filesystem URL
 
 In the Terminal use mdls to see available metadata for a filesystem file
 
 
 Try to make an MDItemRef-
 
 If no MDItemRef is available for this file we go to fallbacks
 
 For the fallback we at least need to fake:
 kMDItemDisplayName - the human readable / localized name of the URL
 kMDItemPath - the path of the URL
 
 kMDItemContentType - the [preferred] UTI of the URL
 kMDItemContentTypeTree - the entire UTI hiearchy (leaving this out of tonights exercise.. I've got this code already but it requires the main thread in a way I'm not going to touch here)
 kMDItemKind - the human readable / localized name of the UTI content type
 
 */

@interface VVMetadataThingus : NSObject < NSURLConnectionDelegate > {

    //	We'll store the original URL used to create this
	NSURL			*itemURL;
    
	//	if possible, use MDItemRef- it uses spotlight services to get info from a disk-based file
	MDItemRef		_mdItem;
	
	//	if an MDItemRef is not available for the URL
	NSDictionary	*_attributes;		//	a dict to store attributes
	
	//	then I can fall-back on using a combintion of FSRef / NSWorkspace / NSFileManager / Launch Services to get *some* of the local file data
	FSRef			_fsRef;				//	an FSRef
	
	//	or if it is a remote thingus we may need to ping it to get a MIME type
    NSURLConnection    *_URLConnection;
    
}

+ (id) createWithURL:(NSURL *)u;
- (id) initWithURL:(NSURL *)u;

- (void) _doFileSystemFallback;
- (void) _doRemoteFallback;

//  internal and delegate methods

//- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;

//	for local files calls MDItemCopyAttribute + autorelease
- (id) valueForAttribute:(id)attribute;

//	for local files calls MDItemCopyAttributes + autorelease
- (NSDictionary *) valuesForAttributes:(NSArray *)attributes;

//	for local files calls MDItemCopyAttributeNames
- (NSArray *) attributes;

//	For easy access to the most common file attributes-
//	returns the [self valueForAttribute:kMDItemPath]
- (NSString *) path;
//	returns the [self valueForAttribute:kMDItemDisplayName]
- (NSString *) displayName;

@end
