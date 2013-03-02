//
//  Tweet.h
//  TweetLocations
//
//  Created by Curtis Sieber on 3/2/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Group;

@interface Tweet : NSManagedObject

@property (nonatomic, retain) NSNumber * favorite;
@property (nonatomic, retain) NSNumber * hasBeenRead;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * listID;
@property (nonatomic, retain) NSNumber * locationFromPic;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * origHTML;
@property (nonatomic, retain) NSString * origURL;
@property (nonatomic, retain) NSData * sourceDict;
@property (nonatomic, retain) NSString * timestamp;
@property (nonatomic, retain) NSString * tweet;
@property (nonatomic, retain) NSNumber * tweetID;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSNumber * fromGoogleReader;
@property (nonatomic, retain) NSString * googleID;
@property (nonatomic, retain) NSString * googleStream;
@property (nonatomic, retain) Group *group;

@end
