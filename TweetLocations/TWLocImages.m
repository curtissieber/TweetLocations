//
//  TWLocImages.m
//  TweetLocations
//
//  Created by Curtis Sieber on 12/16/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocImages.h"

@implementation TWLocImages

- (id)init
{
    self = [super init];
    self->imageDictLock = [[NSLock alloc] init];
    return self;
}

- (NSData*)imageData:(NSString*)url
{
    NSData* data = Nil;
    [self->imageDictLock lock];
    @try {
        data = [self fetchImageForURL:url];
        [self->imageDictLock unlock];
        return data;
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return Nil;
}
- (void)deleteImageData:(NSString*)url
{
    [self->imageDictLock lock];
    @try {
        [self deleteImageForURLFromContext:url];
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)imageData:(NSData*)data forURL:(NSString*)url
{
    [self->imageDictLock lock];
    @try {
        if (data != Nil && url != Nil) {
            if ([self fetchImageForURL:url] == Nil) {
                [self addImageObject:data forURL:url];
            } else
                NSLog(@"delined add of duplicate for %@",url);
        } else
            NSLog(@"Cannot keep image in dictionary, dictionary is Nil");
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (NSData*)fetchImageForURL:(NSString*)url {
    @try {
        ImageItem* image = [self imageFetch:url];
        if (image == Nil)
            return Nil;
        if ([[image class] isSubclassOfClass:[ImageItem class]])
            return [image data];
        return image;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)addImageObject:(NSData*)image forURL:(NSString*)url {
    @try {
        ImageItem* imageItem = [NSEntityDescription insertNewObjectForEntityForName:@"ImageItem" inManagedObjectContext:self.managedObjectContext];
        [imageItem setUrl:url];
        [imageItem setData:image];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)deleteImageForURLFromContext:(NSString*)url {
    @try {
        if (url == Nil) {
            if (_theOtherQueue == Nil) {
                _theOtherQueue = [[NSOperationQueue alloc] init];
                [_theOtherQueue setMaxConcurrentOperationCount:1];
            }
            DeleteImagesOperation* dip = [[DeleteImagesOperation alloc] initWithMaster:self];
            [_theOtherQueue addOperation:dip];
            return;
        }
        id fetchReturn = [self imageFetch:url];
        if (fetchReturn == Nil) return;
        [self.managedObjectContext deleteObject:fetchReturn];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (NSInteger)numImages
{
    NSArray* images = [self imageFetch:Nil];
    return [images count];
}
- (NSInteger)sizeImages
{
    NSString* documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString* database = [documentsDir stringByAppendingPathComponent:@"Images.sqlite"];
    NSDictionary* filevalues = [[NSFileManager defaultManager] attributesOfItemAtPath:database error:Nil];
    NSNumber* fsize = [NSNumber numberWithLongLong:[filevalues fileSize]];
    return [fsize integerValue];
}

- (id)imageFetch:(NSString*)url
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"ImageItem" inManagedObjectContext:self.managedObjectContext];
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
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:Nil cacheName:@"ImageItem"];
    aFetchedResultsController.delegate = Nil;
    
    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        return Nil;
    }
    
    NSArray* results = [aFetchedResultsController fetchedObjects];
    
    if (results != Nil && [results count] > 0) {
        NSLog(@"FETCH for %@ is %d images",url,[results count]);
        if (url == Nil)
            return results;
        return [results objectAtIndex:0];
    }
    
    return Nil;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Images" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Images.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSSQLiteManualVacuumOption,
                             nil];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
        NSLog(@"removed file at %@ due to error",[storeURL description]);
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
    }
    return _persistentStoreCoordinator;
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        NSLog(@"Image file saved");
    }
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
    
    @try {
        NSArray* images = [master imageFetch:Nil];
        if (images != Nil) {
            [master->imageDictLock lock];
            [images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[master managedObjectContext] deleteObject:obj];
                NSLog(@"deleted image %d", idx);
                if (idx == 50) *stop = YES;
            }];
            
            NSLog(@"processing deletes");
            [[master managedObjectContext] processPendingChanges];
            [master->imageDictLock unlock];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSError *error = [[NSError alloc] init];
                [master->imageDictLock lock];
                @try {
                    if (![[master managedObjectContext] save:&error]) {
                        NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
                    }
                    [master->imageDictLock unlock];
                    NSLog(@"Got a chance to save, YAY!");
                } @catch (NSException *eee) {
                    [master->imageDictLock unlock];
                    NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
                }
                if ([images count] > 0) {
                    DeleteImagesOperation* dip = [[DeleteImagesOperation alloc] initWithMaster:master];
                    [[master theOtherQueue] addOperation:dip];
                    [[master theOtherQueue] setSuspended:NO];
                }
            }];
        }
    } @catch (NSException *eee) {
        [master->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    executing = NO; finished = YES;
}

@end
