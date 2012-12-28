//
//  MovieGetter.m
//  PasteParse
//
//  Created by Curtis Sieber on 9/30/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import "MovieGetter.h"

@implementation MovieGetter

@synthesize urlStr, urlResults, saveToThisFile, saveFileHandle, totalSize;

- (void)fetch:(NSURL*)url intoFile:(NSString*)filename urlCallback:(MovieURLCallback)callback
{
    theCallback = callback;
    saveToThisFile = filename;
    saveFileHandle = Nil;
    totalSize = 0;
    
    NSLog(@"fetching %@", [url description]);
    
    // Create the request.
    NSURLRequest *theRequest=[NSURLRequest
                              requestWithURL:url
                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                              timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data
    self->bgTaskTime = CACurrentMediaTime();
    self->bgtask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (theCallback)
            theCallback(totalSize, YES, NO);
    }];
    NSLog(@"began background task %d",self->bgtask);
    NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        //urlData = [NSMutableData data];
        //NSLog(@"initialized receivedData structure");
        [self setTotalSize:0];
        if (![[NSFileManager defaultManager] createFileAtPath:filename contents:Nil attributes:Nil]) {
            NSLog(@"blew it! cannot create %@", filename);
            [theConnection cancel];
        } else {
            saveFileHandle = [NSFileHandle fileHandleForWritingAtPath:filename];
            NSLog(@"Saving to file handle %@",saveFileHandle);
        }
    } else {
        // Inform the user that the connection failed.
        NSLog(@"Connection to %@ failed", url);
        [[UIApplication sharedApplication] endBackgroundTask:bgtask];
        if (theCallback)
            theCallback(totalSize, YES, NO);
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

    if (theCallback)
        theCallback(totalSize, NO, YES);
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    @try {
        //NSLog(@"received data of size %d",[data length]);
        [saveFileHandle writeData:data];
        totalSize += [data length];
        
        if ((CACurrentMediaTime() - self->bgTaskTime) > 60 * 2) {
            // been in the background more than 5 minutes
            UIBackgroundTaskIdentifier oldTask = self->bgtask;
            self->bgtask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                if (theCallback)
                    theCallback(totalSize, YES, NO);
            }];
            NSLog(@"began task %d and will end task %d that is %f seconds old",self->bgtask,oldTask,CACurrentMediaTime() - self->bgTaskTime);
            self->bgTaskTime = CACurrentMediaTime();
            [[UIApplication sharedApplication] endBackgroundTask:oldTask];
        }
        
        if (theCallback)
            theCallback(totalSize, NO, YES);
    } @catch (NSException *e) {
        NSLog(@"Exception %@", [e description]);
    }
}
- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    [saveFileHandle closeFile];
    [[NSFileManager defaultManager] removeItemAtPath:saveToThisFile error:Nil];
    // inform the user
    NSLog(@"Connection failed for movie data! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    [[UIApplication sharedApplication] endBackgroundTask:bgtask];
    if (theCallback)
        theCallback(totalSize, YES, NO);
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    [saveFileHandle closeFile];
    NSLog(@"Succeeded! Saved to file %@", saveToThisFile);
    
    [[UIApplication sharedApplication] endBackgroundTask:bgtask];
    NSLog(@"ended background task %d",self->bgtask);
    if (theCallback)
        theCallback(totalSize, YES, YES);
}
@end
