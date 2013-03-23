//
//  TWLocImages.m
//  TweetLocations
//
//  Created by Curtis Sieber on 12/16/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocImages.h"
#import "TWLocMasterViewController.h"
#import "TWLocDetailViewController.h"

@implementation TWLocImages

- (id)init
{
    self = [super init];
    self->imageDictLock = [[NSLock alloc] init];
    totalImages = -1;
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            NSError* error = [[NSError alloc] init];
            if (![[self managedObjectContext] save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            } //else NSLog(@"Saved thread image");
        } else {
            NSLog(@"ERROR ERROR did not create a new imageItem to store %@",url);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)deleteImageForURLFromContext:(NSString*)url {
    @try {
        if (url == Nil) {
            if (_theOtherQueue == Nil) {
                //_theOtherQueue = [[NSOperationQueue alloc] init];
                //[_theOtherQueue setMaxConcurrentOperationCount:1];
                _theOtherQueue = [NSOperationQueue mainQueue];
            }
            DeleteImagesOperation* dip = [[DeleteImagesOperation alloc] initWithMaster:self];
            [_theOtherQueue addOperation:dip];
            return;
        }
        id fetchReturn = [self imageFetch:url];
        if (fetchReturn == Nil) return;
        if ([[fetchReturn class] isSubclassOfClass:[ImageItem class]]) {
            [[self managedObjectContext] deleteObject:fetchReturn];
            [[self managedObjectContext] processPendingChanges];
            NSError* error = [[NSError alloc] init];
            if (![[self managedObjectContext] save:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            } //else NSLog(@"Saved thread image");
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (NSInteger)numImages
{
    if (totalImages >= 0)
        return totalImages;
    
    @try {
        NSArray* images = [self fetchImages];
        return [images count];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return 0;
}
- (NSInteger)sizeImages
{
    @try {
        NSString* documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString* database = [documentsDir stringByAppendingPathComponent:@"Images.sqlite"];
        NSDictionary* filevalues = [[NSFileManager defaultManager] attributesOfItemAtPath:database error:Nil];
        NSNumber* fsize = [NSNumber numberWithLongLong:[filevalues fileSize]];
        return [fsize integerValue];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return 0;
}

- (id)imageFetch:(NSString*)url
{
    @try {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"ImageItem" inManagedObjectContext:[self managedObjectContext]];
        [fetchRequest setEntity:entity];
        if (url == Nil)
            [fetchRequest setIncludesPropertyValues:NO];
        
        // Set the batch size to a suitable number.
        if (url == Nil)
            [fetchRequest setFetchBatchSize:20];
        else
            [fetchRequest setFetchBatchSize:1];
        
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptorID = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES];
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptorID, nil];
        [fetchRequest setSortDescriptors:sortDescriptors];
        if (url != Nil) {
            NSPredicate* predicate = [NSPredicate predicateWithFormat:@"url == %@",url];
            [fetchRequest setPredicate:predicate];
        }
        
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
        if (url == Nil)
            totalImages = [results count];
        
        if (results != Nil && [results count] > 0) {
            //NSLog(@"FETCH for %@ is %d images",url,[results count]);
            if (url == Nil) {
                NSLog(@"ALL IMAGES FETCH is %d images",[results count]);
                return results;
            }
            return [results objectAtIndex:0];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return Nil;
}

- (NSManagedObjectContext *)managedObjectContext
{
    @try {
        static NSThread* theThread = Nil;
        if (_managedObjectContext != nil) {
            if (theThread != Nil)
                if ([theThread hash] != [[NSThread currentThread] hash]) {
                    NSNumber* hash = [NSNumber numberWithUnsignedInt:[[NSThread currentThread] hash]];
                    NSManagedObjectContext* context = [_mocDict objectForKey:hash];
                    if (context == Nil) {
                        context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
                        [context setParentContext:_managedObjectContext];
                        [_mocDict setObject:context forKey:hash];
                        NSLog(@"image context created for thread %@", hash);
                    }
                    return context;
                }
            return _managedObjectContext;
        }
        
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
            theThread = [NSThread currentThread];
            _mocDict = [[NSMutableDictionary alloc] initWithCapacity:0];
            NSLog(@"setup initial image managedContext for thread %ud %@",[theThread hash],theThread);
        }
        return _managedObjectContext;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return Nil;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    @try {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Images" withExtension:@"momd"];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    @try {
        NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Images.sqlite"];
        
        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                                 //[NSNumber numberWithBool:YES], NSSQLiteManualVacuumOption,
                                 nil];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
            NSLog(@"removed file at %@ due to error",[storeURL description]);
            [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return _persistentStoreCoordinator;
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)notify:(NSString*)text
{
    if (_masterViewController != Nil) {
        [[[(TWLocMasterViewController*)_masterViewController detailViewController] labelOverEverything] setHidden:NO];
        [[[(TWLocMasterViewController*)_masterViewController detailViewController] labelOverEverything] setText:@"SAVING IMAGE CONTEXT"];
    }
}
- (void)dropNotify:(NSString*)text
{
    if (_masterViewController != Nil) {
        [[[(TWLocMasterViewController*)_masterViewController detailViewController] labelOverEverything] setHidden:YES];
    }
}

- (void)saveContext
{
    @try {
        [self performSelector:@selector(notify:) onThread:[NSThread mainThread] withObject:@"SAVING IMAGE CONTEXT" waitUntilDone:YES];
        [self getImageLock];
        NSError *error = nil;
        NSManagedObjectContext *managedObjectContext = _managedObjectContext;
        NSManagedObjectContext *threadContext = [self managedObjectContext];
        if (threadContext != managedObjectContext) {
            NSLog(@"SAVING FROM WRONG THREAD");
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self saveContext];
            }];
        } else if (managedObjectContext != nil) {
            [managedObjectContext processPendingChanges];
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                //abort();
            }
            NSLog(@"Image file saved");
        }
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    [self performSelector:@selector(dropNotify:) onThread:[NSThread mainThread] withObject:Nil waitUntilDone:YES];
}

@end

#pragma mark DELETEIMAGESOPERATION background queue task
@implementation DeleteImagesOperation

- (id)initWithMaster:(TWLocImages*)theMaster
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
    
    NSArray* images = Nil;
    @try {
        images = [master fetchImages];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    if (images != Nil) {
        @try {
            [master getImageLock];
            __block int deletecount = 0;
            [images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[master managedObjectContext] deleteObject:obj];
                deletecount = idx;
                //NSLog(@"deleted image %d", idx);
                if (idx == 50) *stop = YES;
            }];
            NSLog(@"Deleted %d images",deletecount);
            [[master managedObjectContext] processPendingChanges];
            [master->imageDictLock unlock];
        } @catch (NSException *eee) {
            [master->imageDictLock unlock];
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
        
        @try {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                __block NSOperationQueue* queue = [NSOperationQueue currentQueue];
                [master saveContext];
                [queue addOperationWithBlock:^{
                    if ([images count] > 0) {
                        DeleteImagesOperation* dip = [[DeleteImagesOperation alloc] initWithMaster:master];
                        [[master theOtherQueue] addOperation:dip];
                        [[master theOtherQueue] setSuspended:NO];
                    } else {
                        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:@"All images have been deleted from the local store." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                        [alert show];
                    }
                }];
            }];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
    } else {
        @try {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:@"All images have been deleted from the local store." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                [alert show];
            }];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
    }
    executing = NO; finished = YES;
}

@end
