//
//  MovieGetter.h
//  PasteParse
//
//  Created by Curtis Sieber on 9/30/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^MovieURLCallback)(long long dataSize, BOOL complete, BOOL success);

@interface MovieGetter : NSObject {
    NSMutableString* urlStr;
    long long totalSize;
    NSMutableString* urlResults;
    
    NSString* saveToThisFile;
    NSFileHandle* saveFileHandle;
    
    MovieURLCallback theCallback;
    UIBackgroundTaskIdentifier bgtask;
    float bgTaskTime;
}

@property (nonatomic, retain) NSString* urlStr;
@property (nonatomic) long long totalSize;
@property (nonatomic, retain) NSString* urlResults;
@property (nonatomic, retain) NSString* saveToThisFile;
@property (nonatomic, retain) NSFileHandle* saveFileHandle;

- (void)fetch:(NSURL*)url intoFile:(NSString*)filename urlCallback:(MovieURLCallback)callback;

@end
