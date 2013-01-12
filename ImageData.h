//
//  ImageData.h
//  TweetLocations
//
//  Created by Curtis Sieber on 1/5/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ImageItem;

@interface ImageData : NSManagedObject

@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) ImageItem *item;

@end
