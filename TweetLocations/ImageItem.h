//
//  ImageItem.h
//  TweetLocations
//
//  Created by Curtis Sieber on 1/12/13.
//  Copyright (c) 2013 Curtsybear.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface ImageItem : NSManagedObject

@property (nonatomic, retain) id data;
@property (nonatomic, retain) NSString * url;

@end
