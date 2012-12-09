//
//  Account.h
//  TweetLocations2
//
//  Created by Curtis Sieber on 12/9/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Tweet;

@interface Account : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) Tweet *tweets;

@end
