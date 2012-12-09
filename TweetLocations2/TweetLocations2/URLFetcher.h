//
//  URLFetcher.h
//  PasteParse
//
//  Created by Curtis Sieber on 8/4/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^URLCallback)(NSMutableString*);

@interface URLFetcher : NSObject {
    NSMutableString* urlStr;
    NSMutableData* urlData;
    NSMutableString* urlResults;
    
    URLCallback theCallback;
}

@property (nonatomic, retain) NSString* urlStr;
@property (nonatomic, retain) NSMutableData* urlData;
@property (nonatomic, retain) NSString* urlResults;

+ (NSString*)canReplaceURL:(NSString*)url enumerator:(NSEnumerator*)e;
- (void)fetch:(NSString*)url urlCallback:(URLCallback)callback;

@end
