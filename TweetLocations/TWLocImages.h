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

@interface TWLocImages : NSObject {
    @public
    NSLock* imageDictLock;
    @protected
}

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSOperationQueue* theOtherQueue;
@property (strong, nonatomic) NSMutableDictionary* mocDict;

- (NSArray*)fetchImages;
- (NSData*)imageData:(NSString*)url;
- (void)deleteImageData:(NSString*)url;
- (void)imageData:(NSData*)data forURL:(NSString*)url;
- (void)saveContext;
- (NSInteger)numImages;
- (NSInteger)sizeImages;

@end

@interface DeleteImagesOperation : NSOperation {
    TWLocImages* master;
    BOOL executing, finished;
}
- (id)initWithMaster:(TWLocImages*)theMaster;

@end
