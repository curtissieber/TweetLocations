//
//  GoogleReader.h
//  TweetLocations
//
//  Created by Curtis Sieber on 11/2/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GoogleReader : NSObject <UIAlertViewDelegate>

@property (nonatomic, retain) NSString* googleAccount;
@property (nonatomic, retain) NSString* googlePassword;
@property (nonatomic, retain) NSString* googleAuth;
@property (nonatomic, retain) NSString* googleToken;
@property (nonatomic) float googleTokenTime;
@property (nonatomic, retain) NSMutableArray * cookies;

@property (nonatomic, retain) NSString* strSID;
@property (nonatomic, retain) NSString* strLSID;
@property (nonatomic, retain) NSString* strAuth;

- (BOOL)authenticate:(BOOL)again;
- (BOOL)isAuthenticated;
- (NSArray*)getStreams;
- (NSArray *)unreadRSSFeeds;
- (NSArray*)unreadItems:(NSString*)theID;

@end
