//
//  VVMetadataThingus.m
//  MetadataThingus
//
//  Created by David Lublin on 12/17/11.
//  Copyright (c) 2011 Vidvox. All rights reserved.
//

#import "VVMetadataThingus.h"

@implementation VVMetadataThingus

+ (id) createWithURL:(NSURL *)u {
 	if (u==nil)
		return nil;
	
	VVMetadataThingus		*returnMe = [[VVMetadataThingus alloc] initWithURL:u];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}

/*
 
 On init..
 if it is a local file system URL try to make an MDItemRef
 if that fails, or any of the needed metadata is missing do the fallback
 
 if it is a remote URL try to glean the UTI 

 
*/

- (id) initWithURL:(NSURL *)u   {
    NSLog(@"%s",__func__);
    if (self=[super init])  {
        if (u)  {
            itemURL = [u copy];
            NSLog(@"\t\turl %@",itemURL);
            NSString *filePath = [itemURL path];
            NSLog(@"\t\tfile path %@",filePath);
            NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
            if ([fm fileExistsAtPath:filePath])  {
                
                _mdItem = MDItemCreate(NULL, (CFStringRef)filePath);
                
                if (_mdItem==NULL)  {
                    [self _doFileSystemFallback];
                }

            }
            else    {
                [self _doRemoteFallback];
            }
        }
        return self;
    }
    return nil;
}

- (void) dealloc    {
    NSLog(@"%s",__func__);
    if (_URLConnection) {
        [_URLConnection cancel];
        [_URLConnection release];
        _URLConnection = nil;
    }
	if (_mdItem!=NULL)	{
		CFRelease(_mdItem);
		_mdItem = NULL;
	}
	if(_attributes) {
        [_attributes release];
        _attributes = nil;
    }
    [super dealloc];
}

- (void) _doFileSystemFallback    {
    if (itemURL==nil)
        return;
    NSLog(@"%s",__func__);
    NSString *p = [itemURL path];
	NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
	NSMutableDictionary	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
    
	//	MDItem can only work if the drive the file is on was indexed with spotlight
	//	This is the fallback method- uses a combination of NSWorkspace / NSFileManager / FSRef's
	//	to get / track the basic information needed and makes it available using the same keys as MDItem would use
	
	//	First make my fsRef- this is used to track the actual file location if it is moved / renamed
	Boolean		isDirectory;
	OSStatus	status;
	status = FSPathMakeRef ((const UInt8 *)[p fileSystemRepresentation], &_fsRef, &isDirectory);
	NSString	*contentType = nil;
	
	//	The path and file name should be handled dynamically using my FSRef
    
	//	If the FSRef did not work, this might not be a disk based file
	//	Use this fallback for the path / name / content type / etc.
	if (status != 0)	{
		[tmpDict setObject:p forKey:@"kMDItemPath"];
		[tmpDict setObject:[p lastPathComponent] forKey:@"kMDItemFSName"];
		[tmpDict setObject:[p lastPathComponent] forKey:@"kMDItemDisplayName"];
		contentType = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent);	
	}
	else	{
		//	Add the file name and display name.. use the actual file name
		NSString	*displayName = nil;
		
		displayName = [fm displayNameAtPath:p];
		
		if ((displayName == nil)||([displayName	isEqualToString:@""]))
			displayName = [p lastPathComponent];
		
		[tmpDict setObject: displayName forKey:@"kMDItemDisplayName"];
		[tmpDict setObject: displayName forKey:@"kMDItemFSName"];
		
		contentType = [[NSWorkspace sharedWorkspace] typeOfFile:p error:nil];
        
		//	If NSWorkspace fails, try using the UTI services directly
		if (contentType == nil)	{
			if (isDirectory)	{
				contentType = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeDirectory);
			}
			else	{
				contentType = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent);
			}
		}
        
        if (contentType!=nil)   {
            [tmpDict setObject:contentType forKey:@"kMDItemContentType"];
        }
        
        NSArray *contentTypes = (NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent);
        if (contentTypes)   {
            [tmpDict setObject:contentType forKey:@"kMDItemContentTypes"];
        }
	}
    
    //  If desired, other common file system data can be acquired here
    
    _attributes = [[NSDictionary dictionaryWithDictionary:tmpDict] retain];
}

- (void) _doRemoteFallback  {
    if (itemURL==nil)
        return;
    NSLog(@"%s",__func__);
    NSString *p = [itemURL path];
    if (p==nil)
        return;
    NSURLRequest *theRequest=[NSURLRequest requestWithURL:itemURL
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                          timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data
    _URLConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (_URLConnection) {
        [_URLConnection retain];
        NSLog(@"Started URL connection to get MIME type");
    }
    else    {
        NSLog(@"ERROR: NSURLConnection failed");
    }
    /*
    NSMutableDictionary	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
    NSString	*contentType = nil;
    
    contentType = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent);
    
    //  If there is a path extension use that to determine the UTI type
    if ((contentType!=nil)&&([contentType isEqualToString:@""]==NO))    {
        NSLog(@"\t\tfound content type %@",contentType);
		NSString	*displayName = [p lastPathComponent];
		
		[tmpDict setObject: displayName forKey:@"kMDItemDisplayName"];
		[tmpDict setObject: displayName forKey:@"kMDItemFSName"];
        [tmpDict setObject: p forKey:@"kMDItemPath"];
        [tmpDict setObject:contentType forKey:@"kMDItemContentType"];
    }
    //  If the UTI type can't be determined try creating an NSURLConnection
    //  Then use the MIME type from the response
    else    {
        NSURLRequest *theRequest=[NSURLRequest requestWithURL:itemURL
                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                              timeoutInterval:60.0];
        // create the connection with the request
        // and start loading the data
        _URLConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
        if (_URLConnection) {
            [_URLConnection retain];
            NSLog(@"Started URL connection to get MIME type");
        }
        else    {
            NSLog(@"ERROR: NSURLConnection failed");
        }
    }
    _attributes = [[NSDictionary dictionaryWithDictionary:tmpDict] retain];
    */
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response   {
    if (itemURL==nil)
        goto BAIL;
    NSString *p = [itemURL absoluteString];
    if (p==nil)
        goto BAIL;
    NSMutableDictionary	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
    NSString	*contentType = nil;
    
    NSString	*displayName = [p lastPathComponent];
    [tmpDict setObject: displayName forKey:@"kMDItemDisplayName"];
    [tmpDict setObject: displayName forKey:@"kMDItemFSName"];
    [tmpDict setObject: p forKey:@"kMDItemPath"];
    
    contentType = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)[response MIMEType], kUTTypeContent);
    //  If there is a path extension use that to determine the UTI type
    if ((contentType!=nil)&&([contentType isEqualToString:@""]==NO))    {
        [tmpDict setObject:contentType forKey:@"kMDItemContentType"];
    }
    
    NSArray *contentTypes = (NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassMIMEType, (CFStringRef)[response MIMEType], kUTTypeContent);
    if (contentTypes)   {
         [tmpDict setObject:contentType forKey:@"kMDItemContentTypes"];
    }
    
    _attributes = [[NSDictionary dictionaryWithDictionary:tmpDict] retain];
BAIL:
    [_URLConnection cancel];
    [_URLConnection release];
    _URLConnection = nil;
}

//  CANCEL IF THE URL BLAH BLAH AUTH BLAH BLAH FAIL
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge    {
    [_URLConnection cancel];
    [_URLConnection release];
    _URLConnection = nil;     
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error  {
    [_URLConnection cancel];
    [_URLConnection release];
    _URLConnection = nil;    
}

- (id) valueForAttribute:(id)attribute	{
	if (attribute == nil)	{
		return nil;
	}
	id	returnMe = nil;
	
	if (_mdItem!=NULL)	{
        //NSLog(@"\t\titem was not nil!");
		returnMe = [(id)MDItemCopyAttribute(_mdItem, (CFStringRef)attribute) autorelease];
	}
	//	if the MDItem is NULL, use the fallback attributes / fsref
	//	use the fsref to get the item path & file system name - this technique auto-updates along with the changes
	else	{
		if ([attribute isEqualToString:@"kMDItemPath"])	{
			CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &_fsRef);
			if (url != NULL)	{
				returnMe = [(NSString*)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle) autorelease];
				CFRelease(url);
			}
		}
		else if ([attribute isEqualToString:@"kMDItemFSName"])	{
			CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &_fsRef);
			if (url != NULL)	{
				returnMe = [(NSString*)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle) autorelease];
				returnMe = [returnMe lastPathComponent];
				CFRelease(url);
			}
		}
	}
	
	if ((returnMe == nil)&&(_attributes != nil))	{
		//NSLog(@"\t\trequested %@",attribute);
		returnMe = [_attributes objectForKey:attribute];
	}
    
	return returnMe;
}

//	calls MDItemCopyAttributes + autorelease
- (NSDictionary *) valuesForAttributes:(NSArray *)attributes	{
	if (attributes == nil)	{
		return nil;
	}
	NSDictionary *returnMe = nil;
    
	if (_mdItem!=NULL)	{
		returnMe = (NSDictionary *)MDItemCopyAttributes(_mdItem, (CFArrayRef)attributes);
		if (returnMe)
			[returnMe autorelease];
	}
	else if (_attributes!=nil)	{
		NSArray	*objs = [_attributes objectsForKeys:attributes notFoundMarker:[NSNull null]];
		returnMe = [NSDictionary dictionaryWithObjects:objs forKeys:attributes];
	}
	
	return returnMe;
}

//	calls MDItemCopyAttributeNames
//	note that this does not always return all the available attributes! eg. kMDItemPath, kMDItemFSName
- (NSArray *) attributes	{
	NSArray *returnMe = nil;
	
	if (_mdItem!=NULL)
		returnMe = [(NSArray *)MDItemCopyAttributeNames(_mdItem) autorelease];
	else if (_attributes!=nil)
		returnMe = [_attributes allKeys];
	
	return returnMe;
}


- (NSString *) path {
    return [self valueForAttribute:@"kMDItemPath"];    
}

- (NSString *) displayName  {
    return [self valueForAttribute:@"kMDItemDisplayName"];
}

@end
