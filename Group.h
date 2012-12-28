//
//  Group.h
//  TweetLocations
//
//  Created by Curtis Sieber on 12/27/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Tweet;

@interface Group : NSManagedObject

@property (nonatomic, retain) NSString * groupName;
@property (nonatomic, retain) NSSet *tweets;
@end

@interface Group (CoreDataGeneratedAccessors)

- (void)addTweetsObject:(Tweet *)value;
- (void)removeTweetsObject:(Tweet *)value;
- (void)addTweets:(NSSet *)values;
- (void)removeTweets:(NSSet *)values;

@end
