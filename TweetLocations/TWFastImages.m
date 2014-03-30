//
//  TWFastImages.m
//  TweetLocations
//
//  Created by Curtis Sieber on 12/16/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWFastImages.h"

@implementation TWFastImages

- (id)init
{
    self = [super init];
    self->imageDictLock = [[NSLock alloc] init];
    _urlDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
    return self;
}
- (void)getImageLock
{
    float lockDuration = 1.0;
    while ([self->imageDictLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:lockDuration]] == NO) {
        NSLog(@"LOCK LOCK CANNOT UNLOCK in %f seconds",lockDuration);
        if (lockDuration < 5.0)
            lockDuration+= 0.5 ;
    }
}

- (NSArray*)fetchImages
{
    NSArray* data = Nil;
    @try {
        [self getImageLock];
        data = [self fetchImageForURL:Nil];
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    if (data != Nil && [[data class] isSubclassOfClass:[NSArray class]])
        return data;
    return Nil;
}
- (NSData*)imageData:(NSString*)url
{
    NSData* data = Nil;
    @try {
        [self getImageLock];
        data = [self fetchImageForURL:url];
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    if (data != Nil && [[data class] isSubclassOfClass:[NSData class]])
        return data;
    return Nil;
}
- (void)deleteImageData:(NSString*)url
{
    @try {
        [self getImageLock];
        [self deleteImageForURLFromContext:url];
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)imageData:(NSData*)data forURL:(NSString*)url
{
    @try {
        [self getImageLock];
        if (data != Nil && url != Nil) {
            if ([self fetchImageForURL:url] == Nil) {
                [self addImageObject:data forURL:url];
            } //else NSLog(@"delined add of duplicate for %@",url);
        } else
            NSLog(@"Cannot keep image url%@ or data%@ is Nil",url,data);
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (id)fetchImageForURL:(NSString*)url {
    @try {
        ImageItem* image = [self imageFetch:url];
        if (image == Nil)
            return Nil;
        if ([[image class] isSubclassOfClass:[ImageItem class]]) {
            ImageData* imageData = [image data];
            NSData* data = [imageData data];
            return data;
        }
        return image;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)addImageObject:(NSData*)image forURL:(NSString*)url {
    @try {
        ImageItem* imageItem = [NSEntityDescription insertNewObjectForEntityForName:@"ImageItem" inManagedObjectContext:[self managedObjectContext]];
        if (imageItem != Nil) {
            [imageItem setUrl:url];
            ImageData* imageData = [NSEntityDescription insertNewObjectForEntityForName:@"ImageData" inManagedObjectContext:[self managedObjectContext]];
            [imageData setData:image];
            [imageItem setData:imageData];
            totalImages++;
            [[self managedObjectContext] processPendingChanges];
            [_urlDictionary setObject:[NSNumber numberWithBool:YES] forKey:url];
            NSLog(@"added url %@",url);
            NSError* error = [[NSError alloc] init];
            if (![[self managedObjectContext] save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            } else
                NSLog(@"Saved thread image");
        } else {
            NSLog(@"ERROR ERROR did not create a new imageItem to store %@",url);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)deleteImageForURLFromContext:(NSString*)url {
    @try {
        if (url == Nil) {
            if ([self theOtherQueue] == Nil) {
                //_theOtherQueue = [[NSOperationQueue alloc] init];
                //[_theOtherQueue setMaxConcurrentOperationCount:1];
                [self setTheOtherQueue: [NSOperationQueue mainQueue]];
            }
            TWFDeleteImagesOperation* dip = [[TWFDeleteImagesOperation alloc] initWithMaster:self andIndex:0];
            [[self theOtherQueue] addOperation:dip];
            return;
        }
        id fetchReturn = [self imageFetch:url];
        if (fetchReturn == Nil) return;
        if ([[fetchReturn class] isSubclassOfClass:[ImageItem class]]) {
            ImageItem* item = fetchReturn;
            NSLog(@"removing url %@",[item url]);
            [_urlDictionary removeObjectForKey:[item url]];
            [[self managedObjectContext] deleteObject:fetchReturn];
            [[self managedObjectContext] processPendingChanges];
            NSError* error = [[NSError alloc] init];
            if (![[self managedObjectContext] save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            } else
                NSLog(@"Saved thread image");
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (id)imageFetch:(NSString*)url
{
    static NSFetchedResultsController* controller = Nil;
    
    if (controller == Nil) {
        NSLog(@"causing initial fetch");
        controller = [self initialFetch];
    }

    if (url == Nil)
        return [controller fetchedObjects];
    NSNumber* urlexists = [_urlDictionary objectForKey:url];
    if (urlexists == Nil) {
        NSLog(@"URLDOESNOTEXIST NO %@",url);
        return Nil;
    }
    NSLog(@"URLEXISTS YES %@",url);

    NSArray* images = [controller fetchedObjects];
    NSEnumerator* e = [images objectEnumerator];
    ImageItem* item;
    while ((item = [e nextObject]) != Nil && [[item url] isEqualToString:url] == NO) {
        //NSLog(@"checking url %@",[item url]);
    }
    NSLog(@"ended with url %@", [item url]);
    if ([[item url] isEqualToString:url] == NO)
        return Nil;
    NSLog(@"RETURN GOOD IMAGE %@", [item url]);
    return item;
}

- (NSFetchedResultsController*)initialFetch
{
    @try {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"ImageItem" inManagedObjectContext:[self managedObjectContext]];
        [fetchRequest setEntity:entity];
        
        // Set the batch size to a suitable number.
        [fetchRequest setFetchBatchSize:20];
        
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptorID = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES];
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptorID, nil];
        [fetchRequest setSortDescriptors:sortDescriptors];
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[self managedObjectContext] sectionNameKeyPath:Nil cacheName:@"ImageItem"];
        aFetchedResultsController.delegate = Nil;
        
        NSError *error = nil;
        if (![aFetchedResultsController performFetch:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            return Nil;
        }
        
        NSArray* results = [aFetchedResultsController fetchedObjects];
        totalImages = (int)[results count];
        
        if (results != Nil && [results count] > 0) {
            //NSLog(@"FETCH for %@ is %d images",url,[results count]);
            NSLog(@"ALL IMAGES FETCH is %lu images",(unsigned long)[results count]);
            NSEnumerator* e = [results objectEnumerator];
            ImageItem* item;
            while ((item = [e nextObject]) != Nil)
                [_urlDictionary setObject:[NSNumber numberWithBool:YES] forKey:[item url]];
        }
        
        return aFetchedResultsController;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return Nil;
}

@end

#pragma mark DELETEIMAGESOPERATION background queue task
@implementation TWFDeleteImagesOperation

- (id)initWithMaster:(TWFastImages*)theMaster andIndex:(NSUInteger)idx
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    [self setQueuePriority:NSOperationQueuePriorityVeryLow];
    [self setThreadPriority:0.1];
    return self;
}
- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    
    int i;
    NSArray* images = Nil;
    @try {
        images = [master fetchImages];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    if (images != Nil) {
        @try {
            [master saveContext];
            [master getImageLock];
            id obj;
            for (i=0; (index+i) < [images count] && i < 50;
                 i++, obj = [images objectAtIndex:(index+i)]) {
                if (obj != Nil) {
                    ImageItem* item = obj;
                    NSLog(@"deleting url %@",[item url]);
                    if ([item url] != Nil)
                        [[master urlDictionary] removeObjectForKey:[item url]];
                    [[master managedObjectContext] deleteObject:obj];
                    NSLog(@"deleting image %lu", index+i);
                }
            }
            [[master managedObjectContext] processPendingChanges];
            [master->imageDictLock unlock];
        } @catch (NSException *eee) {
            [master->imageDictLock unlock];
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
        
        @try {
            [master saveContext];
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                if ([images count] > index+i) {
                    NSLog(@"still have %lu images, queueing another delete", (unsigned long)[images count]);
                    TWFDeleteImagesOperation* dip = [[TWFDeleteImagesOperation alloc] initWithMaster:master andIndex:index+i];
                    [[master theOtherQueue] addOperation:dip];
                    [[master theOtherQueue] setSuspended:NO];
                } else {
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:@"All images have been deleted from the local store." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                    [alert show];
                }
            }];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    } else {
        @try {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:@"All images have been deleted from the local store." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                [alert show];
            }];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    }
    executing = NO; finished = YES;
}

@end
