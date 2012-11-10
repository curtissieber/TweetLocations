//
//  GoogleReader.h
//  TweetLocations
//
//  Created by Curtis Sieber on 11/2/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GoogleReader : NSObject <UIAlertViewDelegate>

@property (nonatomic) NSString* googleAccount;
@property (nonatomic) NSString* googlePassword;
@property (nonatomic) NSString* googleAuth;
@property (nonatomic) NSString* googleToken;
@property (nonatomic) float googleTokenTime;
@property (nonatomic) id googleUserInfo;

- (BOOL)authenticate:(BOOL)again;
- (BOOL)isAuthenticated;
- (NSArray*)getStreams;

@end
