//
//  ImageItem.h
//  TweetLocations
//
//  Created by Curtis Sieber on 1/19/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ImageData;

@interface ImageItem : NSManagedObject

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) ImageData *data;

@end
