//
//  TWLocImages.h
//  TweetLocations
//
//  Created by Curtis Sieber on 12/16/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ImageItem.h"
#import "ImageData.h"
#import "TWLocImages.h"

@interface TWFastImages : TWLocImages {
}

@property (atomic) NSMutableDictionary* urlDictionary;

@end

@interface TWFDeleteImagesOperation : NSOperation {
    TWFastImages* master;
    BOOL executing, finished;
    NSUInteger index;
}
- (id)initWithMaster:(TWFastImages*)theMaster andIndex:(NSUInteger)idx;

@end
