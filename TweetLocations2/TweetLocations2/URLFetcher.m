//
//  URLFetcher.m
//  PasteParse
//
//  Created by Curtis Sieber on 8/4/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import "URLFetcher.h"

@implementation URLFetcher

@synthesize urlData, urlStr, urlResults;

+ (NSString*)canReplaceURL:(NSString*)url enumerator:(NSEnumerator*)e
{
    NSString* str;
    // if url contains /gwip.me/
    //   then choose the first upload with /upload/
    if ([url rangeOfString:@"/gwip.me/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"/upload/"].location != NSNotFound) {
                return str;
            } else if ([str rangeOfString:@"guyswithiphones.com/2012/"].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@".tumblr.com/image/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@".tumblr.com/tumblr"].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@"/tmblr.co/"].location != NSNotFound ||
               [url rangeOfString:@".tumblr.com/post/"].location != NSNotFound ||
               [url rangeOfString:@"//is.gd/"].location != NSNotFound) {
        NSString* firstJPG = Nil;
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@".tumblr.com/image/"].location != NSNotFound) {
                return str;
            } else if ([str rangeOfString:@"photoset_iframe"].location != NSNotFound) {
                return str;
            } else if ([str rangeOfString:@".tumblr.com/tumblr"].location != NSNotFound) {
                return str;
            } else if ([str rangeOfString:@"media.tumblr.com/"].location != NSNotFound &&
                       [str rangeOfString:@".jpg"].location != NSNotFound) {
                return str;
            }
            if (firstJPG == Nil && [str rangeOfString:@".jpg"].location != NSNotFound)
                firstJPG = str;
            if (firstJPG == Nil && [str rangeOfString:@".jpeg"].location != NSNotFound)
                firstJPG = str;
            
        }
        if (firstJPG != Nil)
            return firstJPG;
    } else if ([url rangeOfString:@"/instagr.am/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"distilleryimage"].location != NSNotFound &&
                [str rangeOfString:@".instagram.com/"].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@"/youtu.be/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"/hqdefault."].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@"youtube.com/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"/hqdefault."].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@"/ow.ly/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"//static.ow.ly/"].location != NSNotFound &&
                [str rangeOfString:@"/normal/"].location != NSNotFound) {
                return str;
            }
        }
    } else if ([url rangeOfString:@"/moby.to/"].location != NSNotFound) {
        while ((str = [e nextObject]) != Nil) {
            if ([str rangeOfString:@"mobypicture.com/"].location != NSNotFound &&
                [str rangeOfString:@"_view."].location != NSNotFound) {
                return str;
            }
        }
    }
    return Nil;
}

- (void)fetch:(NSString*)str urlCallback:(URLCallback)callback
{
    theCallback = callback;
    
    NSLog(@"fetching %@", str);
    
    // Cretate the URL
    NSURL* url = [[NSURL alloc] initWithString:str];
    // Create the request.
    NSURLRequest *theRequest=[NSURLRequest
                              requestWithURL:url
                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                              timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data
    NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        urlData = [NSMutableData data];
        //NSLog(@"initialized receivedData structure");
    } else {
        // Inform the user that the connection failed.
        //NSLog(@"Connection to %@ failed", url);
        if (theCallback)
            theCallback(Nil);
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    //NSLog(@"setting data empty for received  data");
    [urlData setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //NSLog(@"appending data of size %d",[data length]);
    [urlData appendData:data];
}
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    [urlData setLength:0];
    
    // inform the user
    NSLog(@"Connection failed for URL data! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if (theCallback)
        theCallback(Nil);
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    //NSLog(@"Succeeded! Received %d bytes of data",[urlData length]);
    
    [self setUrlStr:[[NSMutableString alloc] initWithData:urlData
                                                 encoding:NSStringEncodingConversionAllowLossy]];
    if (theCallback)
        theCallback(urlStr);
}

@end
