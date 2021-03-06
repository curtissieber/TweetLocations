//
//  TWLocMasterViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocMasterViewController.h"
#import "TWLocDetailViewController.h"
#import "TWLocBigDetailViewController.h"
#import "TWLocCollectionViewController.h"
#import "Image.h"
#import "Tweet.h"
#import "URLFetcher.h"
#import "PhotoGetter.h"

#import <Accounts/Accounts.h>
#import <Twitter/Twitter.h>
#import <ImageIO/ImageIO.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreData/NSFetchedResultsController.h>

@interface TWLocMasterViewController ()
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation TWLocMasterViewController
//@synthesize twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

#define ALERT_DUMMY (0x1)
#define ALERT_NOTWITTER (0x666)
#define ALERT_SELECTACCOUNT (0x1776)
#define ALERT_SETALLREAD (0x1999)
#define ALERT_PATRIALSETREAD (0xbeef)
#define ALERT_REFRESH (0x2001)

static int queuedTasks = 0;
static UILabel* staticQueueLabel = Nil;

+ (void)incrementTasks
{
    queuedTasks++;
}
+ (void)incrementTasks:(int)byNum
{
    queuedTasks+=byNum;
}
+ (void)decrementTasks
{
    queuedTasks--;
}
+ (int)numTasks
{
    return queuedTasks;
}

#pragma mark image

- (void)STATUS:(NSString*)thestatus
{
    @try {
        NSLog(@"%@",thestatus);
        [_statusLabel setText:thestatus];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

static bool NetworkAccessAllowed = NO;
+ (void)setNetworkAccessAllowed:(BOOL)allowed {NetworkAccessAllowed = allowed;}

// will get hit when the user chooses a URL from the text view
// should load the image
-(BOOL)openURL:(NSURL *)url
{
    NSLog(@"master URL:%@",[url absoluteString]);
    if (self.detailViewController != Nil)
        return [self.detailViewController openURL:url];
    return NO;
}

- (void)killMax {
    _twitterIDMax = _twitterIDMin = -1;
    self->maxIDEachList = [[NSMutableDictionary alloc] initWithCapacity:1];
    [self->maxIDEachList setObject:[NSNumber numberWithLongLong:-1] forKey:[NSNumber numberWithLongLong:0]];
}

- (BOOL)lockImageServer
{
    if (self->imageServer == Nil || self->imageLock == Nil) return NO;
    int numTries = 20;
    BOOL gotLock = [self->imageLock tryLock];
    while (gotLock == NO && numTries > 0) {
        numTries--;
        NSLog(@"Waiting on image lock (%d)--",numTries);
        [NSThread sleepForTimeInterval:0.25];
        gotLock = [self->imageLock tryLock];
    }
    if (!gotLock)
        NSLog(@"DEAD DEAD DEAD cannot lock image server!!");
    return gotLock;
}
- (BOOL)unlockImageServer
{
    if (self->imageServer == Nil || self->imageLock == Nil) return NO;
    BOOL wasntLocked = [self->imageLock tryLock];
    [self->imageLock unlock];
    if (wasntLocked) NSLog(@"OOPS OOPS OOPS released an unlocked image server");
    return wasntLocked;
}

static int numImages = 0;
- (TMCache*)getImageServer
{
    if (self->imageServer == Nil) {
        @try {
            self->imageLock = [NSLock new];
            self->imageServer = [[TMCache alloc] initWithName:@"ImageFile"];
            if (! [self lockImageServer]) return Nil;
            if (self->imageServer != Nil) {
                [[self->imageServer diskCache] setByteLimit:500*1024*1024];
                NSLog(@"HDDISK Image Byte Count is %lu",(unsigned long)[[self->imageServer diskCache] byteLimit]);
                [[self->imageServer memoryCache] setCostLimit:20*1024*1024];
                NSLog(@"MEMORY Image Cost Count is %lu",(unsigned long)[[self->imageServer memoryCache] costLimit]);
                NSLog(@"Created the cache, now counting it");
                numImages = 0;
                [[self->imageServer diskCache] enumerateObjectsWithBlock:^(TMDiskCache *cache, NSString *key, id<NSCoding> object, NSURL *fileURL) {
                    if (fileURL != Nil) {
                        numImages++;
                        if (numImages < 5)
                            NSLog(@"FILEURL %@",fileURL);
                    }
                }];
                NSLog(@"enumerated the disk cache for %d items", numImages);
            }
            [self unlockImageServer];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            [self unlockImageServer];
        }
    }
    return self->imageServer;
}

- (NSData*)imageData:(NSString*)url
{
    @try {
        if (! [self lockImageServer]) return Nil;
        NSData* retData = [[self getImageServer] objectForKey:url];
        [self unlockImageServer];
        return retData;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
    return Nil;
}
- (void)deleteImageData:(NSString*)url
{
    @try {
        if (url != Nil) {
            if (! [self lockImageServer]) return;
            [[self getImageServer] objectForKey:url block:^(TMCache *cache, NSString *key, id object) {
                if (object != Nil && key != Nil && [key length] > 0) {
                    [[self getImageServer] removeObjectForKey:key block:^(TMCache *cache, NSString *key, id object) {
                        NSLog(@"removed %@", key);
                    }];
                    numImages--;
                }
            }];
        } else {
            NSString* wasString = [NSString stringWithFormat:@"%d images (%0.2f MB) deleted from the local storage",[self numImages],[self sizeImages]/1024.0/1024.0];
            if (! [self lockImageServer]) return;
            [[self getImageServer] removeAllObjects:^(TMCache *cache) {
                NSLog(@"removed everything setting images to 0");
                numImages = 0;
                [self checkToSeeIfAllDeleted];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:wasString delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                    [alert show];
                }];
            }];
        }
        [self unlockImageServer];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
}
- (void)imageData:(NSData*)data forURL:(NSString*)url
{
    @try {
        if (! [self lockImageServer]) return;
        [[self getImageServer] setObject:data forKey:url];
        [self unlockImageServer];
        numImages++;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
}
- (void)backgroundImageData:(NSData *)data forURL:(NSString *)url
{
    @try {
        if (! [self lockImageServer]) return;
        [[self getImageServer] setObject:data forKey:url block:^(TMCache *cache, NSString *key, id object) {
            NSLog(@"Stored %lu image %@",(unsigned long)[data length],url);
            numImages++;
            [self unlockImageServer];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
}
- (long long)sizeImages
{
    @try {
        if (! [self lockImageServer]) return 0;
        long long imageByteSize = [[self getImageServer] diskByteCount];
        [self unlockImageServer];
        return imageByteSize;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
    return 0;
}
- (int)numImages
{
    return numImages;
}
- (void)clearImageMemoryCache
{
    @try {
        if (! [self lockImageServer]) return;
        [[[self getImageServer] memoryCache] removeAllObjects];
        [self unlockImageServer];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        [self unlockImageServer];
    }
}

- (void)checkToSeeIfAllDeleted
{
    NSURL* directory = [[[self getImageServer] diskCache] cacheURL];
    NSFileManager* fManager = [NSFileManager defaultManager];
    NSArray* files = [fManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:Nil options:0 error:Nil];
    if ([files count] > 1) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE FAILED" message:[NSString stringWithFormat:@"%lu file images still remain in the local store.",(unsigned long)[files count]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
            [alert show];
        }];
    }
}

#pragma mark URL_WORKER
#define MAX_IMG_QUEUE_FOR_DELETE (100)
static NSMutableArray* urlQueue = Nil;
- (void)keepTrackofReadURLs:(NSString*)url
{
    @try {
        if (!urlQueue)
            urlQueue = [[NSMutableArray alloc] initWithCapacity:MAX_IMG_QUEUE_FOR_DELETE];
        if (urlQueue ) {
            __block bool found = NO;
            [urlQueue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString* e = obj;
                if ([e isEqualToString:url])
                    found = *stop = YES;
            }];
            if (found) {
                NSLog(@"updating removal of %@",url);
                [urlQueue removeObject:url];
                [urlQueue addObject:url];
                return;
            }
            NSLog(@"remembering to remove %@",url);
            [urlQueue addObject:url];
            if ([urlQueue count] < MAX_IMG_QUEUE_FOR_DELETE)
                return;
            int urlCount = (int)[urlQueue count];
            
            __block NSString* deleteURL = [urlQueue objectAtIndex:0];
            [urlQueue removeObjectAtIndex:0];
            [_multipleOpQueue addOperationWithBlock:^{
                NSLog(@"Deleting image %d %@",urlCount,deleteURL);
                [self deleteImageData:deleteURL];
            }];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)dropReadURLs:(MasterCallback)callback
{
    @try {
        if (!urlQueue)
            return;
        [urlQueue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* deleteURL = obj;
            NSLog(@"Deleting image %@",deleteURL);
            [self deleteImageData:deleteURL];
        }];
        [urlQueue removeAllObjects];
        if (callback != Nil)
            callback();
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (NSIndexPath*)nextIndex:(NSIndexPath*)index forTable:(UITableView*)table
{
    int numRows = (int)[self.tableView numberOfRowsInSection:index.section];
    int numSections = (int)[self.tableView numberOfSections];
    NSIndexPath* nextindex = Nil;
    if (index.row+1 >= numRows) {
        if (index.section+1 >= numSections)
            return Nil;
        nextindex = [NSIndexPath indexPathForRow:0
                                       inSection:index.section+1];
    } else
        nextindex = [NSIndexPath indexPathForRow:index.row+1
                                       inSection:index.section];
    return nextindex;
}
- (void)nextTweet
{
    @try {
        NSLog(@"NEXT TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        if (selected) [_prevTweets insertObject:selected atIndex:0];
        if ([_prevTweets count] > 50) [_prevTweets removeObjectAtIndex:[_prevTweets count]-1];
        NSIndexPath* nextindex = [self nextIndex:selected forTable:self.tableView];
        //nextindex = [NSIndexPath indexPathForRow:0 inSection:0]; // new, always try at top first
        if (nextindex == Nil)
            return;
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
        
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        
        self.detailViewController.detailItem = object;
        
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        @try {
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)nextNewTweet
{
    @try {
        NSLog(@"NEXT New TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        if (selected) [_prevTweets insertObject:selected atIndex:0];
        if ([_prevTweets count] > 50) [_prevTweets removeObjectAtIndex:[_prevTweets count]-1];
        NSIndexPath* nextindex = [self nextIndex:selected forTable:self.tableView];
        if (_getBestPicNext) {
            nextindex = [NSIndexPath indexPathForRow:0 inSection:0]; // new, always try at top first
            _getBestPicNext = NO;
        }
        if (nextindex == Nil)
            return;
        Tweet *object;
        @try {
            object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            
            while ([[object hasBeenRead]boolValue] == YES &&
                   (nextindex = [self nextIndex:nextindex forTable:self.tableView]) != Nil)
                object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            
            if ([[object hasBeenRead]boolValue] == YES) {
                nextindex = [self nextIndex:selected forTable:self.tableView];
                object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
                NSLog(@"nothing unread, going back to %@",[object timestamp]);
            }
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
        
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        
        self.detailViewController.detailItem = object;
        
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        @try {
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)firstNewTweet:(id)dummy
{
    @try {
        NSLog(@"FIRST New TWEET");
        NSIndexPath* selected = [NSIndexPath indexPathForRow:0 inSection:0];
        if (selected) [_prevTweets insertObject:selected atIndex:0];
        if ([_prevTweets count] > 50) [_prevTweets removeObjectAtIndex:[_prevTweets count]-1];
        NSIndexPath* nextindex = selected;
        if (nextindex == Nil)
            return;
        Tweet *object;
        @try {
            object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            
            while ([[object hasBeenRead]boolValue] == YES &&
                   (nextindex = [self nextIndex:nextindex forTable:self.tableView]) != Nil)
                object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            
            if ([[object hasBeenRead]boolValue] == YES) {
                nextindex = [self nextIndex:selected forTable:self.tableView];
                object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
                NSLog(@"nothing unread, going back to %@",[object timestamp]);
            }
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
        
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        
        self.detailViewController.detailItem = object;
        
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        @try {
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (NSIndexPath*)prevIndex:(NSIndexPath*)index forTable:(UITableView*)table
{
    NSIndexPath* nextindex = Nil;
    if (index.row == 0) {
        if (index.section == 0)
            return Nil;
        nextindex = [NSIndexPath indexPathForRow:0
                                       inSection:index.section-1];
    } else
        nextindex = [NSIndexPath indexPathForRow:index.row-1
                                       inSection:index.section];
    return nextindex;
}
- (void)prevTweet
{
    @try {
        NSLog(@"PREV TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        NSIndexPath* nextindex = [self prevIndex:selected forTable:self.tableView];
        if (nextindex == Nil)
            return;
        if ([_prevTweets count] > 0) {
            nextindex = [_prevTweets objectAtIndex:0];
            [_prevTweets removeObjectAtIndex:0];
            if (([nextindex row] == [selected row]) &&
                ([_prevTweets count] > 0)){
                nextindex = [_prevTweets objectAtIndex:0];
                [_prevTweets removeObjectAtIndex:0];
            }
        }
        @try {
            [self.tableView selectRowAtIndexPath:nextindex
                                        animated:YES
                                  scrollPosition:UITableViewScrollPositionMiddle];
            Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            self.detailViewController.detailItem = object;
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
        
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [self.tableView setNeedsDisplay];
        [context processPendingChanges];
        // Save the context.  But I keep having the queue stop dead at this point BOO
        NSError *error = [[NSError alloc] init];
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
        }
        NSLog(@"Got a chance to save, YAY!");
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)deleteTweet:(Tweet*)tweet
{
    NSLog(@"want to delete tweet %@",[tweet tweetID]);
    @try {
        NSLog(@"NEXT TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        int numRows = (int)[self.tableView numberOfRowsInSection:selected.section];
        int offset=0;
        if (selected.row+1 >= numRows)
            offset = -1;
        
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        @try {
            [context deleteObject:tweet];
            [context processPendingChanges];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
        [self.tableView reloadData];
        
        NSIndexPath* nextindex = [NSIndexPath indexPathForRow:selected.row + offset
                                                    inSection:selected.section];
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
        self.detailViewController.detailItem = object;
        
        [self.tableView setNeedsDisplay];
        [context processPendingChanges];
        // Save the context.  But I keep having the queue stop dead at this point BOO
        NSError *error = [[NSError alloc] init];
        if (![context save:&error]) {
            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
        }
        NSLog(@"Got a chance to save, YAY!");
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)refreshTweet:(Tweet*)tweet
{
    NSLog(@"want to refresh tweet %@ %@",[tweet tweetID], [tweet url]);
    
    @try {
        if ([tweet origURL] != Nil) {
            [_updateQueue addOperationWithBlock:^{
                [tweet setUrl:[tweet origURL]];
            }];
        } else {
            NSArray* urls = [URLProcessor getURLs:[tweet tweet]];
            if ([urls count] > 0) {
                [_updateQueue addOperationWithBlock:^{
                    [tweet setUrl:[urls objectAtIndex:0]];
                }];
            }
        }
        //[tweet setOrigHTML:Nil];
        NSLog(@"refresh gives url %@",[tweet url]);
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context processPendingChanges];
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        
        [self.tableView selectRowAtIndexPath:selected
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        //Tweet *object = [[self fetchedResultsController] objectAtIndexPath:selected];
        //self.detailViewController.detailItem = object;
        [self.detailViewController setDetailItem:tweet];
        [self.detailViewController openURL:[NSURL URLWithString:[tweet origURL]]];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)favoriteTweet:(Tweet*)tweet
{
    NSLog(@"want to FAV tweet %@",[tweet tweetID]);
    if (self->twitterAccount == Nil)
        return;
    @try {
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            // Now make an authenticated request to our endpoint
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            [params setObject:[[tweet tweetID] description] forKey:@"id"];
            
            //  The endpoint that we wish to call
            NSURL *url =
            [NSURL
             URLWithString:@"https://api.twitter.com/1.1/favorites/create.json"];
            
            //  Build the request with our parameter
            SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];
            
            // Attach the account object to this request
            [request setAccount:self->twitterAccount];
            
            [request performRequestWithHandler:
             ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                 // inspect the contents of error
                 NSLog(@"FAVORITE err=%@", error);
                 [_updateQueue addOperationWithBlock:^{
                     [tweet setFavorite:[NSNumber numberWithBool:YES]];
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                         NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
                         UITableViewCell* cell =[self.tableView cellForRowAtIndexPath:selected];
                         [cell setNeedsDisplay];
                         
                         UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"FAVORITEd" message:@"Tweet was favorited." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                         [alert setTag:ALERT_DUMMY];
                         [alert show];
                         [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                             @try {
                                 NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
                                 NSError* error2 = [[NSError alloc] init];
                                 // Save the context.  But I keep having the queue stop dead at this point BOO
                                 if (![context save:&error2]) {
                                     // Replace this implementation with code to handle the error appropriately.
                                     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                                     NSLog(@"Unresolved error saving the context %@, %@", error2, [error2 userInfo]);
                                 }
                                 NSLog(@"Got a chance to save, YAY!");
                             } @catch (NSException *eee) {
                                 NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                             }
                         }];
                     }];
                 }];
             }];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
}

- (void)openInTwitter:(Tweet*)tweet
{
    NSString* tweetID = [[tweet tweetID] description];
    NSString* tweetuser = [tweet username];
    NSString* url = [NSString stringWithFormat:@"https://twitter.com/%@/status/%@", tweetuser, tweetID];
    NSLog(@"twitter open: %@", url);
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: url]];
}

#pragma mark Twitter
#define NUMTWEETSTOGET (2000)

-(void)getTwitterAccount
{
    @try {
        ACAccountStore* accountStore = [[ACAccountStore alloc] init];
        ACAccountType* accountType = [accountStore
                                      accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        [accountStore
         requestAccessToAccountsWithType:accountType
         options:Nil
         completion:^(BOOL granted, NSError *error) {
             if (error != Nil) {
                 NSLog(@"request to access twitter accounts error: %@",
                       [error description]);
                 [_updateQueue addOperationWithBlock:^{
                     [self STATUS:@"Request to access account error"];
                 }];
             }
             NSLog(@"Twitter account access %@ granted",
                   granted ? @"YES, is" : @"NO, is not");
             if (!granted)
                 [self noTwitterAlert];
             else {
                 NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
                 
                 if ([accountArray count] < 1)
                     [self noTwitterAlert];
                 else
                     [self performSelectorOnMainThread:@selector(chooseTwitterAccount:)
                                            withObject:accountArray
                                         waitUntilDone:NO];
             }
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
}

- (void)queueTweetGet:(NSNumber*)listID
{
    @try {
        if (_singleOpQueue) {
            if ([[self.detailViewController activityLabel] isHidden]) {
                [UIView animateWithDuration:0.4 animations:^{
                    [self.detailViewController activityLabel].hidden = NO;
                }];
                [[self.detailViewController activityLabel] setText:@"Getting Tweets:"];
            }
            
            if (listID == Nil) {
//                NSDictionary* listNames = self->lists;
//                [[[listNames keyEnumerator] allObjects] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                    NSNumber* listID = [self->lists objectForKey:(NSString*)obj];
//                    NSLog(@"adding list %@ to the getQueue",listID);
//                    [self->queueGetArray addObject:listID];
//                }];
                
                if ([self.fetchedResultsController fetchedObjects] != Nil) {
                    NSLog(@"current FETCH is %lu tweets",(unsigned long)[[self.fetchedResultsController fetchedObjects] count]);
                    NSEnumerator* e = [[self.fetchedResultsController fetchedObjects] objectEnumerator];
                    Tweet* tweet;
                    while ((tweet = [e nextObject]) != Nil) {
                        long long maxIDlocal = [self getMaxTweetID:[tweet listID]];
                        if ([[tweet tweetID] longLongValue] > maxIDlocal)
                            [self setMaxTweetID:[[tweet tweetID] longLongValue] forList:[tweet listID]];
                    }
                    NSLog(@"done setting up the ID array");
                } else NSLog(@"NO TWEETS FETCHED! IS THE DB EMPTY?");
            }
            
            _twitterIDMax = [self getMaxTweetID:listID];
            
            _nextIDMax = _twitterIDMax;
            if (listID == Nil)
                [self deleteTweetDataFile];
            //[self setMinMaxIDs:listID min:_twitterIDMin max:_twitterIDMax next:_nextIDMax numToGet:_maxTweetsToGet];
            GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self andList:listID];
            [_multipleOpQueue setSuspended:NO];
            [_multipleOpQueue addOperation:getTweetOp];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (long long)getMaxTweetID:(NSNumber*)theListID
{
    long long __block retval = -1;
    if (theListID == Nil)
        theListID = [NSNumber numberWithLongLong:0];
    [self->maxIDEachList enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (key != Nil && [[key class] isSubclassOfClass:[NSNumber class]])
            if ([theListID compare:(NSNumber*)key] == NSOrderedSame)
                if (obj != Nil && [[obj class] isSubclassOfClass:[NSNumber class]])
                    retval = [(NSNumber*)obj longLongValue];
    }];
    
    return retval;
}
- (void)setMaxTweetID:(long long)theMax forList:(NSNumber*)theListID
{
    if (theListID == Nil)
        theListID = [NSNumber numberWithLongLong:0];
    [self->maxIDEachList setObject:[NSNumber numberWithLongLong:theMax] forKey:theListID];
}

- (void)chooseTwitterAccount:(NSArray*)accountArray
{
    @try {
        if (self->twitterAccountName) {
            self.tabBarController.title = self->twitterAccountName;
            ACAccountStore* accountStore = [[ACAccountStore alloc] init];
            ACAccountType* accountType = [accountStore
                                          accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
            NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
            NSEnumerator* e = [accountArray objectEnumerator];
            ACAccount* account = Nil;
            while ((account = [e nextObject]) != Nil) {
                if ([[account username] compare:self->twitterAccountName] == NSOrderedSame)
                    self->twitterAccount = account;
            }
            
            // not going to auto do this [self refreshTweets:Nil];
            [self getMinMaxIDs:Nil]; [self firstNewTweet:Nil]; // do this instead
            [[_detailViewController activityLabel] setHidden:YES];
        }
        
        if (self->twitterAccount != Nil)
            return;
        
        // otherwise, choose an account, since we havent chosen yet
        
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Select Twitter Account"
                                                        message:@"Access which twitter account?"
                                                       delegate:self
                                              cancelButtonTitle: Nil
                                              otherButtonTitles: Nil];
        [alert setTag:ALERT_SELECTACCOUNT];
        NSEnumerator* e = [accountArray objectEnumerator];
        ACAccount* account = Nil;
        while ((account = [e nextObject]) != Nil) {
            NSLog(@"Adding %@ button",[account username]);
            [alert addButtonWithTitle:[account username]];
        }
        [alert addButtonWithTitle:@"CANCEL"];
        NSLog(@"Trying to get the twitter account selection");
        [alert show];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
}

#pragma mark Alerts

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    @try {
        if ([alertView tag] == ALERT_NOTWITTER) {
            // not allowed to exit
            NSLog(@"No twitter accounts.  I'm going to sit and stew.");
        }
        if ([alertView tag] == ALERT_SELECTACCOUNT) {
            NSString* accountName = [alertView buttonTitleAtIndex:buttonIndex];
            NSLog(@"Selected %@ twitter account", accountName);
            if ([accountName compare:@"CANCEL"] != NSOrderedSame) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:accountName forKey:@"twitterAccount"];
                [defaults synchronize];
                self->twitterAccountName = accountName;
                self.tabBarController.title = self->twitterAccountName;
                
                ACAccountStore* accountStore = [[ACAccountStore alloc] init];
                ACAccountType* accountType =
                [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
                NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
                NSEnumerator* e = [accountArray objectEnumerator];
                ACAccount* account = Nil;
                while ((account = [e nextObject]) != Nil) {
                    if ([[account username] compare:accountName] == NSOrderedSame)
                        self->twitterAccount = account;
                }
                
                [self refreshTweets:Nil];
            }
        }
        if ([alertView tag] == ALERT_SETALLREAD) {
            NSString* buttonNameHit = [alertView buttonTitleAtIndex:buttonIndex];
            if ([buttonNameHit isEqualToString:@"CANCEL"])
                NSLog(@"don't set all to read");
            else if ([buttonNameHit isEqualToString:@"TWEETS READ"]) {
                NSLog(@"YES set all to read");
                [self allTweetsNeedToBeSetToRead:Nil];
            } else if ([buttonNameHit isEqualToString:@"PARTIAL SET2READ"]) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSString* username = [[_detailViewController detailItem] username];
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Choose a partial pruning" message:@"Set some tweets to READ, by name or size?" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:[NSString stringWithFormat:@"KILL USER %@", username], @"SMALL PHOTO PRUNING", nil];
                    [alert setTag:ALERT_PATRIALSETREAD];
                    [alert show];
                }];
            } else if ([buttonNameHit isEqualToString:@"DELETE IMAGES"]) {
                NSLog(@"deleting all images");
                [_singleOpQueue addOperationWithBlock:^{
                    [self deleteImageData:Nil]; // removes all image data
                    [self checkForMaxTweets];
                }];
            }
        }
        if ([alertView tag] == ALERT_PATRIALSETREAD) {
            NSString* buttonNameHit = [alertView buttonTitleAtIndex:buttonIndex];
            if ([buttonNameHit isEqualToString:@"CANCEL"])
                NSLog(@"don't set all to read");
            else if ([buttonNameHit rangeOfString:@"KILL"].location != NSNotFound) {
                NSString* username = [[_detailViewController detailItem] username];
                [self allTweetsNeedToBeSetToRead:username];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Setting tweets to read" message:[NSString stringWithFormat:@"setting all tweets from %@ to read",username] delegate:self cancelButtonTitle:@"okay" otherButtonTitles: nil];
                    [alert setTag:ALERT_DUMMY];
                    [alert show];
                }];
            } else if ([buttonNameHit rangeOfString:@"SMALL PHOTO"].location != NSNotFound) {
                NSNumber* picSize = [NSNumber numberWithInt:899];
                [self allTweetsNeedToBeSetToRead:picSize];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Setting tweets to read" message:[NSString stringWithFormat:@"setting all tweets smaller than %@ to read",picSize] delegate:self cancelButtonTitle:@"okay" otherButtonTitles: nil];
                    [alert setTag:ALERT_DUMMY];
                    [alert show];
                }];
            }
        }
        if ([alertView tag] == ALERT_REFRESH) {
            NSString* buttonNameHit = [alertView buttonTitleAtIndex:buttonIndex];
            if ([buttonNameHit isEqualToString:@"Twitter"]) {
                [self refreshTweets:Nil];
            } else if ([buttonNameHit isEqualToString:@"Lists"]) {
                [self listsRefreshTweets];
            } else if ([buttonNameHit isEqualToString:@"otherTwitter"]) {
                [self otherAccountRefreshTweets];
            } else if ([buttonNameHit isEqualToString:@"Geek Statistics" ]) {
                [self geekStatistics];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)geekStatistics
{
    @try {
        NSMutableString* geekString = [[NSMutableString alloc] initWithCapacity:200];
        // start with geeky image info
        [geekString appendString:[NSString stringWithFormat:@"%lu tweets\n%d images %0.2fMB\n\n",(unsigned long)[[self idSet] count],[self numImages], [self sizeImages]/1024.0/1024.0]];
        // [tweet username], [tweet acountListPrefix]
        NSMutableDictionary* listDict = [[NSMutableDictionary alloc] initWithCapacity:10];
        NSMutableDictionary* usernameDict = [[NSMutableDictionary alloc] initWithCapacity:10];
        NSArray* tweets = [[self fetchedResultsController] fetchedObjects];
        [tweets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            Tweet* tweet = obj;
            if (! [[tweet hasBeenRead] boolValue]) {
                NSNumber* listCounter = [listDict objectForKey:[tweet acountListPrefix]];
                if (listCounter == Nil)
                    listCounter = [NSNumber numberWithInt:1];
                else
                    listCounter = [NSNumber numberWithInt:1+[listCounter intValue]];
                [listDict setObject:listCounter forKey:[tweet acountListPrefix]];
                NSNumber* userCounter = [usernameDict objectForKey:[tweet username]];
                if (userCounter == Nil)
                    userCounter = [NSNumber numberWithInt:1];
                else
                    userCounter = [NSNumber numberWithInt:1+[userCounter intValue]];
                [usernameDict setObject:userCounter forKey:[tweet username]];
            }
        }];
        // report counts for each list
        NSArray* keys = [listDict keysSortedByValueUsingSelector:@selector(compare:)];
        keys = [[keys reverseObjectEnumerator] allObjects];
        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* list = obj;
            NSNumber* num = [listDict valueForKey:list];
            [geekString appendString:[NSString stringWithFormat:@"(%d) items in %@\n",[num intValue],list]];
        }];
        // report counts for each username
        keys = [usernameDict keysSortedByValueUsingSelector:@selector(compare:)];
        keys = [[keys reverseObjectEnumerator] allObjects];
        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* user = obj;
            NSNumber* num = [usernameDict valueForKey:user];
            NSNumber* score = [[self scoringDictionary] objectForKey:user];
            NSString* scoreString = @"";
            if (score != Nil)
                scoreString = [NSString stringWithFormat:@" [SCORE %d]", [score intValue]];
            [geekString appendString:[NSString stringWithFormat:@"(%d) posted by %@ %@\n",[num intValue],user,scoreString]];
        }];
        
        [geekString appendString:@"\n\nCURRENT SCORES:\n"];
        // report all scores
        keys = [[self scoringDictionary] keysSortedByValueUsingSelector:@selector(compare:)];
        keys = [[keys reverseObjectEnumerator] allObjects];
        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* user = obj;
            NSNumber* num = [[self scoringDictionary] valueForKey:user];
            [geekString appendString:[NSString stringWithFormat:@" %@ score %d\n",user,[num intValue]]];
        }];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[self.detailViewController activityLabel] setText:geekString];
            [[self.detailViewController activityLabel] setHidden:NO];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

#pragma mark Tweets
#define MAXTWEETS (500)
#define TWEETREQUESTSIZE (200)

static NSMutableDictionary* minMaxDict = Nil;
- (void)getMinMaxIDs:(NSNumber*)listID
{
    @try {
        if (minMaxDict == Nil) {
            @try {
                NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"minMaxIDs.dict"];
                NSData *content = [NSData dataWithContentsOfFile:fileName];
                NSString* jsonString = [[NSString alloc] initWithBytes:[content bytes] length:[content length] encoding:NSUTF8StringEncoding];
                NSLog(@"minmaxDict file: %@",jsonString);
                if (content == Nil) {
                    minMaxDict = [[NSMutableDictionary alloc] initWithCapacity:1];
                } else {
                    NSError *jsonError;
                    id json = [NSJSONSerialization JSONObjectWithData:content
                                                              options:NSJSONReadingMutableLeaves
                                                                error:&jsonError];
                    if (json != Nil) {
                        while (json != Nil && [[json class] isSubclassOfClass:[NSArray class]]) {
                            NSArray* arr = json;
                            if ([arr count] > 0)
                                json = [arr objectAtIndex:0];
                            else
                                json = Nil;
                        }
                        if (json != Nil && [[json class] isSubclassOfClass:[NSDictionary class]]) {
                            minMaxDict = [[NSMutableDictionary alloc] initWithDictionary:json];
                            NSLog(@"minmaxDict READ: %@",minMaxDict);
                        } else
                            minMaxDict = [[NSMutableDictionary alloc] initWithCapacity:1];
                    }
                    else {
                        // inspect the contents of jsonError
                        NSLog(@"GET minmaxDict err=%@", jsonError);
                        minMaxDict = [[NSMutableDictionary alloc] initWithCapacity:1];
                    }
                }
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                minMaxDict = Nil;
            }
            if (minMaxDict == Nil)
                minMaxDict = [[NSMutableDictionary alloc] init];
            _twitterIDMax = -1;
            _twitterIDMin = -1;
            _nextIDMax = _twitterIDMax;
            _maxTweetsToGet = NUMTWEETSTOGET;
        }
        NSString* minstr = [NSString stringWithFormat:@"%@:%@:min",[self->twitterAccount username],listID];
        NSString* maxstr = [NSString stringWithFormat:@"%@:%@:max",[self->twitterAccount username],listID];
        NSString* nextstr = [NSString stringWithFormat:@"%@:%@:next",[self->twitterAccount username],listID];
        NSString* numstr = [NSString stringWithFormat:@"%@:%@:num",[self->twitterAccount username],listID];
        NSNumber* minnum = [minMaxDict objectForKey:minstr];
        NSNumber* maxnum = [minMaxDict objectForKey:maxstr];
        NSNumber* nextnum = [minMaxDict objectForKey:nextstr];
        NSNumber* numnum = [minMaxDict objectForKey:numstr];
        _twitterIDMin = (minnum == Nil) ? -1 : [minnum longLongValue];
        _twitterIDMax = (maxnum == Nil) ? -1 : [maxnum longLongValue];
        _nextIDMax = (nextnum == Nil) ? _twitterIDMax : [nextnum longLongValue];
        _maxTweetsToGet = (numnum == Nil) ? NUMTWEETSTOGET : [numnum longLongValue];
        
        NSLog(@"got minmax (%@) min:%lld max:%lld next:%lld num:%lld", listID, _twitterIDMin, _twitterIDMax, _nextIDMax, _maxTweetsToGet);
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)setMinMaxIDs:(NSNumber*)listID min:(long long)min max:(long long)max next:(long long)next numToGet:(long long)numToGet
{
    @try {
        NSLog(@"setting minmax (%@) min:%lld max:%lld next:%lld num:%lld", listID, _twitterIDMin, _twitterIDMax, _nextIDMax, _maxTweetsToGet);
        if (minMaxDict == Nil)
            [self getMinMaxIDs:listID];
        NSString* minstr = [NSString stringWithFormat:@"%@:%@:min",[self->twitterAccount username],listID];
        NSString* maxstr = [NSString stringWithFormat:@"%@:%@:max",[self->twitterAccount username],listID];
        NSString* nextstr = [NSString stringWithFormat:@"%@:%@:next",[self->twitterAccount username],listID];
        NSString* numstr = [NSString stringWithFormat:@"%@:%@:num",[self->twitterAccount username],listID];
        
        [minMaxDict setObject:[NSNumber numberWithLongLong:min] forKey:minstr];
        [minMaxDict setObject:[NSNumber numberWithLongLong:max] forKey:maxstr];
        [minMaxDict setObject:[NSNumber numberWithLongLong:next] forKey:nextstr];
        [minMaxDict setObject:[NSNumber numberWithLongLong:numToGet] forKey:numstr];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)stowMinMaxIDs
{
    @try {
        if (minMaxDict == nil) return;
        
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"minMaxIDs.dict"];
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        //append text to file (you'll probably want to add a newline every write)
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:minMaxDict options:NSJSONWritingPrettyPrinted error:nil];
        NSString* jsonString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
        NSLog(@"SAVING minMax: %@", jsonString);
        NSError *error;
        [jsonString writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:&error];
        NSLog(@"WROTE ERR=%@",error);
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)getTweets:(NSNumber*)listID
{
    if (self->twitterAccount == Nil)
        return;
    
    @try {
        
        [self getMinMaxIDs:listID];
        NSLog(@"list %@ min:%lld max:%lld next:%lld 2get:%lld", listID, _twitterIDMin, _twitterIDMax, _nextIDMax, _maxTweetsToGet);
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:@"1" forKey:@"include_entities"];
        
        //  The endpoint that we wish to call
        NSURL *url;
        NSString* requestSize = [NSString stringWithFormat:@"%d",TWEETREQUESTSIZE];
        url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
        if (listID != Nil) {
            url = [NSURL URLWithString:@"https://api.twitter.com/1.1/lists/statuses.json"];
            NSLog(@"List URL = %@",[url absoluteString]);
            [params setObject:[self->twitterAccount username] forKey:@"screen_name"];
            [params setObject:requestSize forKey:@"count"];
            [params setObject:[listID stringValue] forKey:@"list_id"];
        } else
            [params setObject:requestSize forKey:@"count"];
        if (_twitterIDMax > 0)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMax] forKey:@"since_id"];
        if (_twitterIDMin > 0 && _twitterIDMin != _twitterIDMax)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMin] forKey:@"max_id"];
        NSLog(@"getting tweets max=%lld min=%lld", _twitterIDMax, _twitterIDMin);
        
        //  Build the request with our parameter
        SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"****************\ngetting tweets max=%lld min=%lld\n", _twitterIDMax, _twitterIDMin]];
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"URL= %@\n", [url absoluteString]]];
        [_updateQueue addOperationWithBlock:^{
            [self STATUS:@"Requesting tweets"];
        }];
        
        [request performRequestWithHandler:
         ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
             if (!responseData) {
                 // inspect the contents of error
                 NSLog(@"GET TWEETS err=%@", error);
             }
             else {
                 NSError *jsonError;
                 NSArray *timeline =
                 [NSJSONSerialization JSONObjectWithData:responseData
                                                 options:NSJSONReadingMutableLeaves
                                                   error:&jsonError];
                 if (timeline) {
                     // at this point, we have an object that we can parse
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                         NSString* listname = @"TIMELINE";
                         if (listID != Nil) {
                             NSArray* keys = [self->lists allKeysForObject:listID];
                             if (keys != Nil && [keys count] > 0)
                                 listname = [keys objectAtIndex:0];
                         }
                     }];
                     [self saveTweetDebugToFile:[NSString stringWithFormat:@"received %lu tweets\n", (unsigned long)[timeline count]]];
                     [self saveTweetDataToFile:responseData];
                     
                     if (_singleOpQueue != Nil) {
                         NSLog(@"adding storetweet size=%lu to the Queue", (unsigned long)[timeline count]);
                         StoreTweetOperation* storeTweetOp = [[StoreTweetOperation alloc] initWithMaster:self timeline:timeline andList:listID];
                         [_updateQueue setSuspended:NO];
                         [_updateQueue addOperation:storeTweetOp];
                     }
                 }
                 else {
                     // inspect the contents of jsonError
                     NSLog(@"GET TWEET JSON err=%@", jsonError);
                 }
             }
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)storeTweets:(NSArray*)timeline andList:(NSNumber*)theListID
{
    @try {
        int storedTweets = 0;
        __block BOOL twitterErrorDetected = NO;
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
        __block NSMutableDictionary* summary = [[NSMutableDictionary alloc] initWithCapacity:1];
        
        //TODO need to add a check here for error: JSON returns
        if ([[timeline class] isSubclassOfClass:[NSDictionary class]]) {
            NSDictionary* errorSet = (NSDictionary*)timeline;
            NSArray* errors = [errorSet objectForKey:@"errors"];
            [errors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSDictionary* theError = obj;
                NSString* message = [theError objectForKey:@"message"];
                NSNumber* errNo = [theError objectForKey:@"code"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString* status = [[self.detailViewController activityLabel] text];
                    [[self.detailViewController activityLabel]
                     setText:[NSString
                              stringWithFormat:@"%@\nTwitter Error (%@) %@",status,errNo,message]];
                });
                twitterErrorDetected = YES;
                NSLog(@"TWITTER ERROR: (%@) %@",errNo,message);
            }];
            timeline = [[NSArray alloc] init]; // nothing to process
        }
        
        NSEnumerator* e = [timeline objectEnumerator];
        NSDictionary* item;
        
        NSLog(@"storing %lu tweets",(unsigned long)[timeline count]);
        while ((item = [e nextObject]) != Nil &&
               [[item class] isSubclassOfClass:[NSDictionary class]]) {
            @try {
                NSMutableString* theUrl = [[NSMutableString alloc] initWithString:@""];
                NSString* username = @"";
                double latitude = -999, longitude = -999;
                NSNumber* theID = [item objectForKey:@"id"];
                NSNumber* favorited = [item objectForKey:@"favorited"];
                NSString* timestamp = [item objectForKey:@"created_at"];
                NSString* theText = [item objectForKey:@"text"];
                //NSLog(@"Tweet %@ %@",theID,theText);
                NSDictionary* users = [item objectForKey:@"user"];
                if (users != Nil) {
                    username = [users objectForKey:@"screen_name"];
                    //NSLog(@"   screenName=%@",username);
                }
                NSDictionary* theCoords = [item objectForKey:@"coordinates"];
                //NSLog(@"   coord=%@",theCoords);
                if (theCoords != Nil &&
                    [[theCoords class] isSubclassOfClass:[NSDictionary class]]) {
                    NSArray* coordArray = [theCoords objectForKey:@"coordinates"];
                    NSString* coordtype = [theCoords objectForKey:@"type"];
                    if (coordtype != Nil &&
                        [coordtype compare:@"Point"] == NSOrderedSame &&
                        coordArray != Nil &&
                        [coordArray count] > 1) {
                        longitude = [(NSString*)[coordArray objectAtIndex:0] doubleValue];
                        latitude = [(NSString*)[coordArray objectAtIndex:1] doubleValue];
                    }
                }
                NSDictionary* entities = [item objectForKey:@"entities"];
                if (entities != Nil) {
                    NSArray* urlsArray = [entities objectForKey:@"urls"];
                    if (urlsArray != Nil && [urlsArray count] > 0) {
                        if ([urlsArray count] > 1)
                            NSLog(@"multiple urls items %@",[urlsArray componentsJoinedByString:@" , "]);
                        /*NSDictionary* urls = [urlsArray lastObject];
                        if (urls != Nil) {
                            theUrl = [urls objectForKey:@"expanded_url"];
                            //NSLog(@"   url=%@",theUrl);
                        }
                        if (urls == Nil || theUrl == Nil)
                            NSLog(@"bad last urls item in %@ ???",[urlsArray componentsJoinedByString:@" , "]);*/
                        [urlsArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            NSDictionary* urls = [urlsArray lastObject];
                            if (urls != Nil) {
                                NSString* anotherURL = [urls objectForKey:@"expanded_url"];
                                if (![anotherURL respondsToSelector:@selector(rangeOfString:)])
                                    ;
                                else if ([anotherURL rangeOfString:@"/4sq.com/"].location != NSNotFound)
                                    ;
                                else if ([anotherURL rangeOfString:@"/huff.to/"].location != NSNotFound)
                                    ;
                                else if (anotherURL != Nil && [anotherURL length] > 4) {
                                    [theUrl appendString:anotherURL];
                                    [theUrl appendString:@"\n"];
                                }
                            }
                        }];
                    }
                    NSArray* media = [entities objectForKey:@"media"];
                    if (media != Nil && [media count] > 0) {
                        if ([media count] > 1)
                            NSLog(@"multiple media items %@",[media componentsJoinedByString:@" , "]);
                        /*NSDictionary* mediaItem = [media lastObject];
                        if (mediaItem != Nil) {
                            NSString* anotherURL = [mediaItem objectForKey:@"media_url"];
                            if (anotherURL != Nil && [anotherURL length] > 4) {
                                theUrl = anotherURL;
                                //NSLog(@"   url=%@",theUrl);
                            }
                        }
                        if (mediaItem == Nil || theUrl == Nil)
                            NSLog(@"bad last media item in %@ ???",[media componentsJoinedByString:@" , "]);*/
                        [media enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            NSDictionary* mediaItem = [media lastObject];
                            if (mediaItem != Nil) {
                                NSString* anotherURL = [mediaItem objectForKey:@"media_url"];
                                if (![anotherURL respondsToSelector:@selector(rangeOfString:)])
                                    ;
                                else if ([anotherURL rangeOfString:@"/4sq.com/"].location != NSNotFound)
                                    ;
                                else if ([anotherURL rangeOfString:@"/huff.to/"].location != NSNotFound)
                                    ;
                                else if (anotherURL != Nil && [anotherURL length] > 4) {
                                    [theUrl appendString:anotherURL];
                                    [theUrl appendString:@"\n"];
                                }
                            }
                        }];
                    }
                }
                
                BOOL duplicate = NO;
                if (([theID longLongValue] == _twitterIDMin) ||
                    ([theID longLongValue] == _twitterIDMax))
                    duplicate = YES;
                if ([theID longLongValue] > _nextIDMax) {
                    _nextIDMax = [theID longLongValue];
                }
                if ([theID longLongValue] < _twitterIDMin ||
                    _twitterIDMin <= 0) {
                    _twitterIDMin = [theID longLongValue];
                }
                NSSet* dups = Nil;
                if (!duplicate) {
                    dups = [_idSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                        *stop = ([(NSNumber*)obj isEqualToNumber:theID]);
                        return *stop;
                    }];
                    if (dups != Nil && [dups count] > 0)
                        duplicate = YES;
                }
                Tweet *tweet = Nil;
                if (!duplicate) {
                    if ([theUrl length] > 4) {
                        tweet = [NSEntityDescription insertNewObjectForEntityForName:[entity name]
                                                              inManagedObjectContext:context];
                        [tweet setSourceDict:[NSKeyedArchiver archivedDataWithRootObject:item]];
                        [tweet setTweetID:theID];
                        [tweet setFavorite:favorited];
                        [tweet setTimestamp:timestamp];
                        [tweet setUsername:username];
                        [tweet setTweet:theText];
                        [tweet setLatitude:[NSNumber numberWithDouble:latitude]];
                        [tweet setLongitude:[NSNumber numberWithDouble:longitude]];
                        [tweet setHasPicSize:[NSNumber numberWithInt:0]];
                        [tweet setUserScore:[NSNumber numberWithInteger:[self scoreForUser:username]]];
                        [tweet setUrl:theUrl];
                        [tweet setOrigURL:[[theUrl componentsSeparatedByString:@"\n"] firstObject]];
                        [tweet setOrigHTML:Nil];
                        [tweet setLocationFromPic:[NSNumber numberWithBool:NO]];
                        [tweet setHasBeenRead:[NSNumber numberWithBool:NO]];
                        NSString* acctString = @"TIMELINE";
                        if (theListID != Nil) {
                            [tweet setListID:theListID];
                            NSArray* keys = [self->lists allKeysForObject:theListID];
                            if (keys != Nil && [keys count] > 0)
                                acctString = [keys objectAtIndex:0];
                        } else {
                            [tweet setListID:[NSNumber numberWithLongLong:0]];
                        }
                        acctString = [NSString stringWithFormat:@"%@/%@/",[self->twitterAccount username],acctString];
                        [tweet setAcountListPrefix:acctString];
                        
                        [_idSet addObject:theID];
                        storedTweets++;
                        
                        NSNumber* numtweets = [summary objectForKey:username];
                        if (numtweets == Nil) {
                            [summary setObject:[NSNumber numberWithInt:1] forKey:username];
                        } else {
                            numtweets = [NSNumber numberWithInt:[numtweets intValue]+1];
                            [summary setObject:numtweets forKey:username];
                        }
                    }
                    [self saveTweetDebugToFile:[NSString stringWithFormat:@"original tweet %@\n",theID]];
                } else {
                    [self saveTweetDebugToFile:[NSString stringWithFormat:@"DUP      tweet %@\n",theID]];
                }
                
            } @catch (NSException* eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
        }
        NSString* blurb = [NSString stringWithFormat:@"Done storing %lu tweets (%d real tweets)",(unsigned long)[timeline count], storedTweets];
        NSLog(@"%@",blurb);
        [self saveTweetDebugToFile:blurb];
        
        _maxTweetsToGet -= [timeline count];
        NSLog(@"got %lu tweets, %lld more to get", (unsigned long)[timeline count], _maxTweetsToGet);
        [_updateQueue addOperationWithBlock:^{
            NSString* listname = @"TIMELINE";
            if (theListID != Nil) {
                NSArray* keys = [self->lists allKeysForObject:theListID];
                if (keys != Nil && [keys count] > 0)
                    listname = [keys objectAtIndex:0];
            }
            NSMutableString* summaryString = [[NSMutableString alloc] initWithString:@""];
            [summary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [summaryString appendFormat:@"\n    %@ = %d", key, [(NSNumber*)obj intValue]];
            }];
            NSString* status = [[self.detailViewController activityLabel] text];
            [[self.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\nRetrieved %d new (%lu dumped) tweets from the %@ area%@",status,storedTweets,[timeline count]-storedTweets,listname, summaryString]];
            status = [NSString stringWithFormat:@"Storing %@ tweets [%d]",listname, storedTweets];
            [self STATUS:status];
        }];
        
        if (_singleOpQueue != Nil && storedTweets > 0 &&
            !([timeline count] < (TWEETREQUESTSIZE/2) || _maxTweetsToGet < 1)) {
            NSLog(@"adding another getTweet to the Queue");
            [self setMinMaxIDs:theListID min:_twitterIDMin max:_twitterIDMax next:_nextIDMax numToGet:_maxTweetsToGet];
            GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self andList:theListID];
            [_multipleOpQueue setSuspended:NO];
            [_multipleOpQueue addOperation:getTweetOp];
        } else {
            if (_nextIDMax > 0)
                _twitterIDMax = _nextIDMax;
            else
                [self saveTweetDebugToFile:[NSString stringWithFormat:@"did not get a new twitterIDMax\n"]];
            [self saveTweetDebugToFile:[NSString stringWithFormat:@"new twitterIDMax %lld\n",_twitterIDMax]];
            NSLog(@"new TwitterIDMax %lld",_twitterIDMax);
            [_updateQueue addOperationWithBlock:^{
                [self STATUS:[NSString stringWithFormat:@"%lu tweets: %d images %0.2fMB",(unsigned long)[_idSet count],[self numImages], [self sizeImages]/1024.0/1024.0]];
            }];
            
            // important to reset the min and next and num2get after done with all gets for a source
            [self setMinMaxIDs:theListID min:-1 max:_twitterIDMax next:-1 numToGet:NUMTWEETSTOGET];
            
            // now, let us do the next item in the queue
            if (!twitterErrorDetected && [self->queueGetArray count] > 0) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self.tableView setNeedsDisplay];
                    [context processPendingChanges];
                    // Save the context.  But I keep having the queue stop dead at this point BOO
                    @try {
                        NSError *error = [[NSError alloc] init];
                        if (![context save:&error]) {
                            // Replace this implementation with code to handle the error appropriately.
                            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
                        }
                        NSLog(@"Got a chance to save, YAY!");
                        [self.tableView reloadData];
                        
                    } @catch (NSException *eee) {
                        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                    }
                }];
                NSLog(@"Done with current list %@",theListID);
                NSNumber* nextListID = [self->queueGetArray objectAtIndex:0];
                [self->queueGetArray removeObjectAtIndex:0];
                NSLog(@"queueing the next list %@",nextListID);
                [self queueTweetGet:nextListID];
            } else {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self.tableView setNeedsDisplay];
                    [context processPendingChanges];
                    // Save the context.  But I keep having the queue stop dead at this point BOO
                    @try {
                        NSError *error = [[NSError alloc] init];
                        if (![context save:&error]) {
                            // Replace this implementation with code to handle the error appropriately.
                            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
                        }
                        NSLog(@"Got a chance to save, YAY!");
                        [self.tableView reloadData];
                        
                        NSEnumerator* e = [[self.fetchedResultsController fetchedObjects] objectEnumerator];
                        Tweet* tweet;
                        while ((tweet = [e nextObject]) != Nil) {
                            if (_singleOpQueue != Nil && NetworkAccessAllowed &&
                                [[tweet hasBeenRead] boolValue] == NO) {
                                NSIndexPath* indexPath = [self.fetchedResultsController indexPathForObject:tweet];
                                if (indexPath != Nil) {
                                    TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet
                                                                                          index:indexPath
                                                                           masterViewController:self
                                                                                     replaceURL:Nil];
                                    [_multipleOpQueue addOperation:top];
                                    [_multipleOpQueue setSuspended:NO];
                                }
                            }
                        }
                    } @catch (NSException *eee) {
                        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                    }
                    NSString* status = [[self.detailViewController activityLabel] text];
                    [[self.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\nNote: currently storing %d images, of size %0.2fMB",status,[self numImages], [self sizeImages]/1024.0/1024.0]];
                    [self performSelector:@selector(firstNewTweet:) withObject:Nil afterDelay:2.0];
                }];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (NSDictionary*)getTwitterLists:(BOOL)queueGets callback:(MasterListsCallback)callback
{
    NSMutableDictionary* returnDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    ACAccountStore* accountStore = [[ACAccountStore alloc] init];
    ACAccountType* accountType = [accountStore
                                  accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
    NSEnumerator* e = [accountArray objectEnumerator];
    ACAccount* account = Nil;
    while ((account = [e nextObject]) != Nil) {
        if ([[account username] compare:self->twitterAccountName] == NSOrderedSame)
            self->twitterAccount = account;
    }
    if (self->twitterAccount == Nil)
        return returnDict;
    
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[self->twitterAccount username] forKey:@"screen_name"];
        [params setObject:@"1" forKey:@"include_entities"];
//        if (_twitterIDMax > 0)
//            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMax] forKey:@"since_id"];
//        [params setObject:@"50" forKey:@"count"];
//        if (_twitterIDMin > 0 && _twitterIDMin != _twitterIDMax)
//            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMin] forKey:@"max_id"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/lists/list.json"];
        
        //  Build the request with our parameter
        SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"URL= %@\n", [url absoluteString]]];
        
        [request performRequestWithHandler:
         ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
             if (!responseData) {
                 // inspect the contents of error
                 NSLog(@"GET LISTS err=%@", error);
             }
             else {
                 NSError *jsonError;
                 NSArray *listArray =
                 [NSJSONSerialization JSONObjectWithData:responseData
                                                 options:NSJSONReadingMutableLeaves
                                                   error:&jsonError];
                 if ([listArray respondsToSelector:@selector(enumerateObjectsUsingBlock:)])
                     [listArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                         @try {
                             NSDictionary* aList = obj;
                             NSString* listName = [NSString stringWithFormat:@"%@ (%@)",[aList objectForKey:@"name"],[aList objectForKey:@"member_count"]];
                             NSNumber* listID = [aList objectForKey:@"id"];
                             if (listName != Nil && listID != Nil) {
                                 [returnDict setObject:listID forKey:listName];
                                 if (queueGets) {
                                     [self getMinMaxIDs:listID];
                                     [self setMinMaxIDs:listID min:-1 max:_twitterIDMax next:-1 numToGet:NUMTWEETSTOGET];
                                     [self newList:listID name:listName];
                                     NSLog(@"Adding list %@ ID=%@ account=%@",listName,listID,[self->twitterAccount username]);
                                     [self->queueGetArray addObject:listID];
                                 }
                             }
                         } @catch (NSException *eee) {
                             NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                         }
                     }];
             }
             self->lists = returnDict;
             if (queueGets && [self->queueGetArray count] > 0)
                 [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                     NSNumber* listID =[self->queueGetArray objectAtIndex:0];
                     [self->queueGetArray removeObjectAtIndex:0];
                     [self queueTweetGet:listID];
                 }];
             if (callback != Nil)
                 callback(returnDict);
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return returnDict;
}
- (NSDictionary*)specialGetTwitterLists:(BOOL)queueGets callback:(MasterListsCallback)callback
{
    NSMutableDictionary* returnDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    ACAccountStore* accountStore = [[ACAccountStore alloc] init];
    ACAccountType* accountType = [accountStore
                                  accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
    NSEnumerator* e = [accountArray objectEnumerator];
    ACAccount* account = Nil;
    while ((account = [e nextObject]) != Nil) {
        if ([[account username] compare:SPECIAL_TWITTER_ACCOUNT_NAME] == NSOrderedSame)
            self->twitterAccount = account;
    }
    
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[self->twitterAccount username] forKey:@"screen_name"];
        [params setObject:@"1" forKey:@"include_entities"];
//        if (_twitterIDMax > 0)
//            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMax] forKey:@"since_id"];
//        [params setObject:@"50" forKey:@"count"];
//        if (_twitterIDMin > 0 && _twitterIDMin != _twitterIDMax)
//            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMin] forKey:@"max_id"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/lists/list.json"];
        
        //  Build the request with our parameter
        SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        NSLog(@"getting twitter lists");
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"****************\ngetting twitter lists"]];
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"URL= %@\n", [url absoluteString]]];
        
        [request performRequestWithHandler:
         ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
             if (!responseData) {
                 // inspect the contents of error
                 NSLog(@"GET LISTS err=%@", error);
             }
             else {
                 NSError *jsonError;
                 NSArray *listArray =
                 [NSJSONSerialization JSONObjectWithData:responseData
                                                 options:NSJSONReadingMutableLeaves
                                                   error:&jsonError];
                 if ([listArray respondsToSelector:@selector(enumerateObjectsUsingBlock:)])
                     [listArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                         @try {
                             NSDictionary* aList = obj;
                             NSString* listName = [NSString stringWithFormat:@"%@ (%@)",[aList objectForKey:@"name"],[aList objectForKey:@"member_count"]];
                             NSNumber* listID = [aList objectForKey:@"id"];
                             if (listName != Nil && listID != Nil) {
                                 [returnDict setObject:listID forKey:listName];
                                 [self newList:listID name:listName];
                                 NSLog(@"Adding list %@ ID=%@",listName,listID);
                                 if (queueGets) if ([listName rangeOfString:@"list" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                                     [self getMinMaxIDs:listID];
                                     [self setMinMaxIDs:listID min:-1 max:_twitterIDMax next:-1 numToGet:NUMTWEETSTOGET];
                                     [self->queueGetArray addObject:listID];
                                     NSLog(@"Adding list %@ ID=%@ account=%@",listName,listID,[self->twitterAccount username]);
                                 }
                             }
                         } @catch (NSException *eee) {
                             NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
                         }
                     }];
             }
             self->lists = returnDict;
             if (queueGets && [self->queueGetArray count] > 0)
                 [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                     NSNumber* listID =[self->queueGetArray objectAtIndex:0];
                     [self->queueGetArray removeObjectAtIndex:0];
                     [self queueTweetGet:listID];
                 }];
             if (callback != Nil)
                 callback(returnDict);
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return returnDict;
}

- (void)addUser:(NSString*)twitterName toListSlug:(NSString*)listName inAccount:(NSString*)accountName
{
    ACAccountStore* accountStore = [[ACAccountStore alloc] init];
    ACAccountType* accountType = [accountStore
                                  accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
    NSEnumerator* e = [accountArray objectEnumerator];
    ACAccount* account = Nil;
    while ((account = [e nextObject]) != Nil) {
        if ([[account username] compare:accountName] == NSOrderedSame)
            self->twitterAccount = account;
    }
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[self->twitterAccount username] forKey:@"owner_screen_name"];
        [params setObject:twitterName forKey:@"screen_name"];
        [params setObject:listName forKey:@"slug"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/lists/members/create.json"];
        
        //  Build the request with our parameter
        SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        NSLog(@"adding user %@ to list %@ for user %@", twitterName, listName, [self->twitterAccount username]);
        NSLog(@"%@",[NSString stringWithFormat:@"URL= %@\n", [url absoluteString]]);
        
        [request performRequestWithHandler:
         ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
             if (!responseData) {
                 // inspect the contents of error
                 NSLog(@"ADD TO LIST err=%@", error);
             }
             else {
                 if ([urlResponse statusCode] == 200) {
                     UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:[NSString stringWithFormat:@"Added user %@ to list %@ for user %@", twitterName, listName, [self->twitterAccount username]] delegate:self cancelButtonTitle:@"YAY" otherButtonTitles: nil];
                     [alert setTag:ALERT_DUMMY];
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                         [alert show];
                     }];
                 } else {
                     NSLog(@"ADD TO LIST returned %@\n::\n%@",urlResponse,[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                     NSString* message = [NSString stringWithFormat:@"ERROR %ld adding %@ to list %@ for account %@\n%@", (long)[urlResponse statusCode], twitterName, listName, [self->twitterAccount username], [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]];
                     UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:message delegate:self cancelButtonTitle:@"YAY" otherButtonTitles: nil];
                     [alert setTag:ALERT_DUMMY];
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                         [alert show];
                     }];
                 }
             }
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)removeUserFromAllLists:(NSString*)user
{
    NSLog(@"removeUserFromAllLists:%@",user);
    [self getTwitterLists:NO callback:^(NSDictionary *dict) {
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString* str = key;
            int start = (int)[str rangeOfString:@"("].location;
            str = [str stringByReplacingCharactersInRange:NSMakeRange(start - 1, [str length]+1-start) withString:@""];
            [self removeUser:user fromListSlug:str inAccount:self->twitterAccountName];
            [NSThread sleepForTimeInterval:0.5];
        }];
        [self specialGetTwitterLists:NO callback:^(NSDictionary *dict) {
            [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                NSString* str = key;
                int start = (int)[str rangeOfString:@"("].location;
                str = [str stringByReplacingCharactersInRange:NSMakeRange(start - 1, [str length]+1-start) withString:@""];
                [self removeUser:user fromListSlug:str inAccount:SPECIAL_TWITTER_ACCOUNT_NAME];
                [NSThread sleepForTimeInterval:0.5];
            }];
        }];
    }];
}
- (void)removeUser:(NSString*)user fromListSlug:(NSString*)list inAccount:(NSString*)accountName
{
    NSLog(@"UNSUPPORTED YET removeUser:%@ fromList:%@ inAccount:%@",user,list,accountName);
    ACAccountStore* accountStore = [[ACAccountStore alloc] init];
    ACAccountType* accountType = [accountStore
                                  accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
    NSEnumerator* e = [accountArray objectEnumerator];
    ACAccount* account = Nil;
    while ((account = [e nextObject]) != Nil) {
        if ([[account username] compare:accountName] == NSOrderedSame)
            self->twitterAccount = account;
    }
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[self->twitterAccount username] forKey:@"owner_screen_name"];
        [params setObject:user forKey:@"screen_name"];
        [params setObject:list forKey:@"slug"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/lists/members/destroy.json"];
        
        //  Build the request with our parameter
        SLRequest *request =[SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:url parameters:params];
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        NSLog(@"Removing user %@ from list %@ for user %@", user, list, [self->twitterAccount username]);
        NSLog(@"%@",[NSString stringWithFormat:@"URL= %@\n", [url absoluteString]]);
        
        [request performRequestWithHandler:
         ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
             if (!responseData) {
                 // inspect the contents of error
                 NSLog(@"REMOVE FROM LIST err=%@", error);
             }
             else {
                 if ([urlResponse statusCode] == 200) {
                     UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:[NSString stringWithFormat:@"Removed user %@ from list %@ for user %@", user, list, [self->twitterAccount username]] delegate:self cancelButtonTitle:@"YAY" otherButtonTitles: nil];
                     [alert setTag:ALERT_DUMMY];
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                         [alert show];
                     }];
                 } //else NSLog(@"REMOVE FROM LIST returned %@\n::\n%@",urlResponse,[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
             }
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)newList:(NSNumber*)theListID name:(NSString*)theListName
{
    @try {
        if (self->maxIDEachList == Nil)
            self->maxIDEachList = [[NSMutableDictionary alloc] initWithCapacity:0];
        BOOL __block found = NO;
        [self->maxIDEachList enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (key != Nil && [[key class] isSubclassOfClass:[NSNumber class]]) {
                NSNumber* listID = key;
                if ([theListID compare:listID] == NSOrderedSame)
                    found = YES;
            }
        }];
        if (!found) {
            NSLog(@"Adding list tracker for %@ list (%@)",theListName,theListID);
            [self->maxIDEachList setObject:[NSNumber numberWithLongLong:-1] forKey:theListID];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)noTwitterAlert
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"No Twitter Accounts"
                                                        message:@"A twitter account must to be set up in the Settings for this device, and access must be allowed for this application"
                                                       delegate:self
                                              cancelButtonTitle:@"Understood, EXIT"
                                              otherButtonTitles: nil];
        [alert setTag:ALERT_NOTWITTER];
        [alert show];
    }];
}

- (void)setAllTweetsRead:(id)sender
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"All Done?" message:@"Set all tweets to READ, or delete images?" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"PARTIAL SET2READ", @"DELETE IMAGES", @"TWEETS READ", nil];
    [alert setTag:ALERT_SETALLREAD];
    [alert show];
    return; // don't delete, don't set things to "read" state
}
- (void)allTweetsNeedToBeSetToRead:(id)argument
{
    @try {
        NSString* username = Nil;
        NSNumber* picSize = Nil;
        if ([[argument class] isSubclassOfClass:[NSString class]])
            username = argument;
        if ([[argument class] isSubclassOfClass:[NSNumber class]])
            picSize = argument;
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
            NSError* theError;
            NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"tweetID > 0"]];
            NSArray* results = Nil;
            @try {
                results = [context executeFetchRequest:fetchRequest error:&theError];
            } @catch (NSException* eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
            Tweet* tweet = Nil;
            NSEnumerator* e = [results objectEnumerator];
            int counter = 0;
            while ((tweet = [e nextObject]) != Nil) {
                if ([[tweet hasBeenRead] boolValue] == NO) {
                    if ([[tweet locationFromPic] boolValue] == NO) {
                        if (username == Nil && picSize == Nil) {
                            [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
                            [self keepTrackofReadURLs:[tweet url]];
                        } else if (username != Nil && [username isEqualToString:[tweet username]]) {
                            [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
                            [self keepTrackofReadURLs:[tweet url]];
                        } else if (picSize != Nil) {
                            if ([[tweet hasPicSize] intValue] > 0 && [[tweet hasPicSize] intValue] < [picSize intValue]) {
                                __block bool hasVideo = NO;
                                [[URLProcessor getURLs:[tweet origHTML]] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                    NSString* theURL = obj;
                                    if ([URLProcessor isVideoFileURL:theURL]){
                                        hasVideo = *stop = YES;
                                    }
                                }];
                                if (!hasVideo) { // retain movies
                                    [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
                                    [self keepTrackofReadURLs:[tweet url]];
                                } else
                                    NSLog(@"KEEPING %@ due to VIDEO %@", [tweet username], [tweet tweet]);
                            } else
                                NSLog(@"KEEPING %@ due to PIC SIZE %@", [tweet username], [tweet tweet]);
                        }
                    }
                }
                counter++;
                if ((counter%250) == 0) {
                    [self.tableView setNeedsDisplay];
                    [context processPendingChanges];
                    [NSThread sleepForTimeInterval:0.1];
                }
            }
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            @try {
                NSError *error = [[NSError alloc] init];
                if (![context save:&error]) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
                }
                NSLog(@"Got a chance to save, YAY!");
                [self.tableView reloadData];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
            if (username == Nil && picSize == Nil) {
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ALL SET TO READ" message:@"All tweets have been set to READ" delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                [alert setTag:ALERT_DUMMY];
                [alert show];
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)refreshTweetsButton:(id)sender
{
    @try {
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
            [self.tableView reloadData];
            
            [self checkForMaxTweets];
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"TIMELINE or a list?" message:@"grab twitter, lists, or otherTwitter?" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"Twitter", @"Lists", @"otherTwitter", @"Geek Statistics", nil];
            [alert setTag:ALERT_REFRESH];
            [alert show];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)refreshTweets:(id)sender
{
    @try {
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
            [self.tableView reloadData];
            
            [[self.detailViewController activityLabel] setText:@"Getting Tweets:"];
            [self checkForMaxTweets];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                ACAccountStore* accountStore = [[ACAccountStore alloc] init];
                ACAccountType* accountType = [accountStore
                                              accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
                NSArray* accountArray = [accountStore accountsWithAccountType:accountType];
                NSEnumerator* e = [accountArray objectEnumerator];
                ACAccount* account = Nil;
                while ((account = [e nextObject]) != Nil) {
                    if ([[account username] compare:self->twitterAccountName] == NSOrderedSame)
                        self->twitterAccount = account;
                }
                [self queueTweetGet:Nil];
            }];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void) listsRefreshTweets
{
    @try {
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
            [self.tableView reloadData];
            
            [[self.detailViewController activityLabel] setText:@"Getting Tweets:"];
            [self checkForMaxTweets];
            [self getTwitterLists:YES callback:Nil];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void) otherAccountRefreshTweets
{
    @try {
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [self.tableView setNeedsDisplay];
            [context processPendingChanges];
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
            [self.tableView reloadData];
            
            [[self.detailViewController activityLabel] setText:@"Getting Tweets:"];
            [self checkForMaxTweets];
            [self specialGetTwitterLists:YES callback:Nil];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)checkForMaxTweets
{
    @try {
        [_updateQueue addOperationWithBlock:^{
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            NSArray* sections = [self.fetchedResultsController sections];
            for (int sect=0; sect < [sections count]; sect ++) {
                id<NSFetchedResultsSectionInfo> section = [sections objectAtIndex:sect];
                int rows = (int)[section numberOfObjects];
                NSLog(@"sections=%lu row[0]=%d",(unsigned long)[sections count],rows);
                if (rows > MAXTWEETS) {
                    NSLog(@"More than %d tweets in section %@, going to remove some", MAXTWEETS, [section name]);
                    for (int i = rows-1; i >= 0; i--) {
                        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:i inSection:sect];
                        Tweet *tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
                        bool deleteMe = [[tweet hasBeenRead] boolValue];
                        /*if (i < MAXTWEETS+100) {
                            if ([[tweet locationFromPic] boolValue] == YES)
                                deleteMe = NO;
                            if ([[tweet favorite] boolValue] == YES)
                                deleteMe = NO;
                        }*/
                        if (deleteMe) {
                            //NSLog(@"removing %d tweet %@",i,tweet);
                            __block NSString* url = [[[tweet url] componentsSeparatedByString:@"\n"] firstObject];
                            [context deleteObject:tweet];
                            [_idSet removeObject:[tweet tweetID]];
                            [_updateQueue addOperationWithBlock:^{
                                [self deleteImageData:url];
                            }];
                        }
                    }
                }
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
    [_updateQueue addOperationWithBlock:^{
        @try {
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [context processPendingChanges];
            [self.tableView reloadData];
            NSString* status = [[NSString alloc] initWithFormat: @"Tweet Count = %lu", (unsigned long)[_idSet count]];
            [self STATUS:status];
            
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self saveContext];
            }];
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    }];
}

- (void)saveTweetDataToFile:(NSData*)jsonData
{
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString* filename = [documentsDirectory
                              stringByAppendingPathComponent:
                              @"Twitter.JSON.data.txt"];
        NSLog(@"appending JSON to %@",filename);
        
        NSFileHandle* saveFileHandle = [NSFileHandle fileHandleForWritingAtPath:filename];
        [saveFileHandle seekToEndOfFile];
        [saveFileHandle writeData:jsonData];
        [saveFileHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [saveFileHandle closeFile];
        NSLog(@"Succeeded! Saved to file %@", filename);
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)saveTweetDebugToFile:(NSString*)someString
{
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString* filename = [documentsDirectory
                              stringByAppendingPathComponent:
                              @"Twitter.JSON.data.txt"];
        
        NSFileHandle* saveFileHandle = [NSFileHandle fileHandleForWritingAtPath:filename];
        [saveFileHandle seekToEndOfFile];
        [saveFileHandle writeData:[someString dataUsingEncoding:NSUTF8StringEncoding]];
        [saveFileHandle closeFile];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
- (void)deleteTweetDataFile
{
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString* filename = [documentsDirectory
                              stringByAppendingPathComponent:
                              @"Twitter.JSON.data.txt"];
        NSLog(@"Deleting %@",filename);
        if (![[NSFileManager defaultManager] createFileAtPath:filename contents:Nil attributes:Nil]) {
            NSLog(@"blew it! cannot create %@", filename);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

#pragma mark autogenerated

- (void)awakeFromNib
{
    [self getImageServer];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y < 44) {
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(CGRectGetHeight(self.statusLabel.bounds) - MAX(scrollView.contentOffset.y, 0), 0, 0, 0);
    } else {
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }
    
    CGRect statusFrame = self.statusLabel.frame;
    statusFrame.origin.y = scrollView.contentOffset.y; //MIN(scrollView.contentOffset.y, 0);
    self.statusLabel.frame = statusFrame;
    
    CGRect queueFrame = self.queueLabel.frame;
    queueFrame.origin.y = scrollView.contentOffset.y; //MIN(scrollView.contentOffset.y, 0);
    self.queueLabel.frame = queueFrame;
}

- (void)viewDidLoad
{
    [self getImageServer];
    _prevTweets = [[NSMutableArray alloc] init];
    [super viewDidLoad];
    _getBestPicNext = YES;
    
    if ([[NSThread currentThread] hash] == [[NSThread mainThread] hash] ) {
        NSLog(@"dummy data imageData controller get:%@",[self imageData:@"dummy url"]);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"dispatching dummy data imageData controller get:%@",[self imageData:@"dummy url"]);
        });
    }
    
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                      target:self
                                      action:@selector(refreshTweetsButton:)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    UIBarButtonItem *allRead = [[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                target:self
                                action:@selector(setAllTweetsRead:)];
    self.navigationItem.leftBarButtonItem = allRead;
    self.detailViewController = (TWLocBigDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    [self.detailViewController setMaster:self];
    [[self.detailViewController activityLabel] setHidden:YES];
    [[self.detailViewController labelOverEverything] setHidden:YES];
    [self setTitle:@"Twitter"];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"LocPin" ofType:@"png"];
    self.pinImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"LocPinLink" ofType:@"png"];
    self.pinLinkImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"LocPinLinkGreen" ofType:@"png"];
    self.pinLinkPinImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"redX" ofType:@"png"];
    self.redX = [[UIImage alloc] initWithContentsOfFile:filePath];
    
    queuedTasks = 0;
    staticQueueLabel = _queueLabel;
    self->queueGetArray = [[NSMutableArray alloc] initWithCapacity:0];
    _updateQueue = [NSOperationQueue mainQueue];
    _multipleOpQueue = [[NSOperationQueue alloc] init];
    [_multipleOpQueue setMaxConcurrentOperationCount:5];
    _singleOpQueue = [[NSOperationQueue alloc] init];
    [_singleOpQueue setMaxConcurrentOperationCount:1];
    
    SCNetworkReachabilityFlags flags;
    BOOL receivedFlags;
    NetworkAccessAllowed = YES;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), [@"google.com" UTF8String]);
    receivedFlags = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!receivedFlags || (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        NSLog(@"Cannot do nothing on cell network, that's a very bad idea");
        [TWLocMasterViewController setNetworkAccessAllowed:NO];
        [_statusLabel setBackgroundColor:[UIColor yellowColor]];
    } else {
        [TWLocMasterViewController setNetworkAccessAllowed:YES];
        [_statusLabel setBackgroundColor:[UIColor whiteColor]];
        NSLog(@"Network access is allowed, YAY!");
    }
    
    _tweetLibrary = YES;
    
    if (_tweetLibrary) {
        self->twitterAccount = Nil;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        self->twitterAccountName = [defaults objectForKey:@"twitterAccount"];
        _twitterIDMax = -1;
        _nextIDMax = -1;
        _twitterIDMin = -1; // for the grab, make certain to grab it all
        [self killMax];
        [self getTwitterAccount];
    }
    
    backgroundTaskNumber = UIBackgroundTaskInvalid;
    NSTimer* timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeInterval:3.0
                                                                          sinceDate:[NSDate date]]
                                              interval:0.7
                                                target:self
                                              selector:@selector(timerFireMethod:)
                                              userInfo:Nil
                                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}
static UIBackgroundTaskIdentifier backgroundTaskNumber;

- (void)timerFireMethod:(NSTimer*)theTimer
{
    @try {
        if (queuedTasks > 0) {
            if (backgroundTaskNumber == UIBackgroundTaskInvalid)
                [self beginBackgroundTaskHolder];
        } else {
            if (backgroundTaskNumber != UIBackgroundTaskInvalid)
                [self stopBackgroundTaskHolder];
        }
        [_queueLabel setText:[NSString stringWithFormat:@"%d tasks",queuedTasks]];
        if (queuedTasks > 0)
            [self setTitle:[NSString stringWithFormat:@"Twitter %d",queuedTasks]];
        else
            [self setTitle:@"Twitter"];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}
-(void)stopBackgroundTaskHolder {
    NSLog(@"STOPPING BACKGROUND TASK %lu", (unsigned long)backgroundTaskNumber);
    if (backgroundTaskNumber != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskNumber];
        backgroundTaskNumber = UIBackgroundTaskInvalid;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self saveContext];
            if ([[[self detailViewController] class] isSubclassOfClass:[TWLocCollectionViewController class]])
            {
                TWLocCollectionViewController* colView = (TWLocCollectionViewController*)[self detailViewController];
                [[colView collectionView] reloadData];
            }
        }];
    }
    _getBestPicNext = YES;
}
-(void)beginBackgroundTaskHolder {
    backgroundTaskNumber = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self stopBackgroundTaskHolder];
        [self beginBackgroundTaskHolder];
    }];
    NSLog(@"STARTING BACKGROUND TASK %lu", (unsigned long)backgroundTaskNumber);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    @try {
        NSLog(@"MEMORY WARNING in master view");
        [self clearImageMemoryCache];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)insertNewObject:(id)sender
{
    return;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	// Display the authors' names as section headings.
    return [[[self.fetchedResultsController sections] objectAtIndex:section] name];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        // sometimes an assertion failure DEAD DEAD DEAD
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
        
        [self configureCell:cell atIndexPath:indexPath];
        return cell;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return Nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath) [_prevTweets insertObject:indexPath atIndex:0];
    if ([_prevTweets count] > 50) [_prevTweets removeObjectAtIndex:[_prevTweets count]-1];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        self.detailViewController.detailItem = object;
        [self.detailViewController setMaster:self];
    } else {
        [self.detailViewController setMaster:self];
    }
    [_updateQueue addOperationWithBlock:^{
        // Save the context.  But I keep having the queue stop dead at this point BOO
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSError *error = [[NSError alloc] init];
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
        }
        NSLog(@"Got a chance to save, YAY!");
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    @try {
        if ([[segue identifier] isEqualToString:@"showDetail"]) {
            NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            if (indexPath) [_prevTweets insertObject:indexPath atIndex:0];
            if ([_prevTweets count] > 50) [_prevTweets removeObjectAtIndex:[_prevTweets count]-1];
            Tweet *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
            [_updateQueue addOperationWithBlock:^{
                [object setHasBeenRead:[NSNumber numberWithBool:YES]];
                [self keepTrackofReadURLs:[object url]];
            }];
            [[segue destinationViewController] setDetailItem:object];
            self.detailViewController = [segue destinationViewController];
            [self.detailViewController setMaster:self];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    [_updateQueue addOperationWithBlock:^{
        @try {
            // Save the context.  But I keep having the queue stop dead at this point BOO
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            NSError *error = [[NSError alloc] init];
            if (![context save:&error]) {
                NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
            }
            NSLog(@"Got a chance to save, YAY!");
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        }
    }];
}

- (int)unreadTweets
{
    __block int unreadReturn = 0;
    @try {
        NSFetchedResultsController* controller = [self fetchedResultsController];
        if (controller != Nil) {
            NSArray* tweets = [controller fetchedObjects];
            if (tweets != Nil) {
                [tweets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    Tweet* tweet = obj;
                    if ([[tweet hasBeenRead] boolValue] != YES)
                        unreadReturn++;
                }];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return unreadReturn;
}

- (Tweet*)tweetAtIndex:(int)index
{
    Tweet* retTweet = Nil;
    @try {
        NSFetchedResultsController* controller = [self fetchedResultsController];
        if (controller != Nil) {
            NSArray* tweets = [controller fetchedObjects];
            if (tweets != Nil) {
                if (index < [tweets count]) {
                    retTweet = [tweets objectAtIndex:index];
                }
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    return  retTweet;
}

#pragma mark - Fetched results controller
- (void)saveContext
{
    // nothing to do to save the images, TMCache does it
}

- (NSFetchedResultsController *)fetchedResultsController
{
    @try {
        if (_fetchedResultsController == Nil) {
            
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            // Edit the entity name as appropriate.
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Tweet" inManagedObjectContext:[self.managedObjectContext managedObjectContext]];
            [fetchRequest setEntity:entity];
            
            // Set the batch size to a suitable number.
            [fetchRequest setFetchBatchSize:20];
            
            // Edit the sort key as appropriate.
            //NSSortDescriptor *sortDescriptorhasGPS = [[NSSortDescriptor alloc] initWithKey:@"locationFromPic" ascending:NO];
            NSSortDescriptor *sortDescriptorPicSize = [[NSSortDescriptor alloc] initWithKey:@"hasPicSize" ascending:NO];
            //NSSortDescriptor *sortDescriptorUserScore = [[NSSortDescriptor alloc] initWithKey:@"userScore" ascending:NO];
            //NSSortDescriptor *sortDescriptorhasBeenRead = [[NSSortDescriptor alloc] initWithKey:@"hasBeenRead" ascending:YES];
            NSSortDescriptor *sortDescriptorID = [[NSSortDescriptor alloc] initWithKey:@"tweetID" ascending:NO];
            NSArray *sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptorPicSize,sortDescriptorID, nil];
            
            [fetchRequest setSortDescriptors:sortDescriptors];
            
            // Edit the section name key path and cache name if appropriate.
            // nil for section name key path means "no sections".
            NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[self.managedObjectContext managedObjectContext] sectionNameKeyPath:Nil cacheName:@"Master"];
            aFetchedResultsController.delegate = self;
            self.fetchedResultsController = aFetchedResultsController;
            
            NSError *error = nil;
            if (![self.fetchedResultsController performFetch:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            
            _idSet = [[NSMutableSet alloc] initWithCapacity:1000];
            
            if ([self.fetchedResultsController fetchedObjects] != Nil) {
                NSLog(@"Initital FETCH is %lu tweets",(unsigned long)[[self.fetchedResultsController fetchedObjects] count]);
                [self saveTweetDebugToFile:[NSString stringWithFormat:@"Initital FETCH is %lu tweets\n",(unsigned long)[[self.fetchedResultsController fetchedObjects] count]]];
                NSEnumerator* e = [[self.fetchedResultsController fetchedObjects] objectEnumerator];
                Tweet* tweet;
                while ((tweet = [e nextObject]) != Nil) {
                    [_idSet addObject:[tweet tweetID]];
                }
                NSLog(@"done setting up the ID array");
            } else NSLog(@"NO TWEETS FETCHED! IS THE DB EMPTY?");
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        return Nil;
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
 // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
 {
 // In the simplest, most efficient, case, reload the table view.
 [self.tableView reloadData];
 }
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    @try {
        Tweet *tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        [self cellSetup:cell forTweet:tweet];
        
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
}

- (void)cellSetup:(UITableViewCell *)cell forTweet:(Tweet*)tweet
{
    if (cell == Nil || tweet == Nil)
        return;
    
    @try {
        cell.textLabel.text = [[NSString alloc] initWithFormat:@"[%@]:%@",
                               [tweet username], [tweet tweet] ];
        UIFont* font = [[cell textLabel] font];
        CGSize descriptionHeight = [cell.textLabel.text sizeWithFont:font
                                                   constrainedToSize:[cell textLabel].frame.size
                                                       lineBreakMode:[[cell textLabel] lineBreakMode]];
        CGRect frame = [cell.textLabel frame];
        frame.size.height = descriptionHeight.height;
        [cell.textLabel setFrame:frame];
        CGRect detailFrame = [cell.detailTextLabel frame];
        detailFrame.origin.y = frame.size.height + frame.origin.y * 2;
        [cell.detailTextLabel setFrame:detailFrame];
        CGRect cellFrame = [cell frame];
        cellFrame.size.height = detailFrame.origin.y + detailFrame.size.height;
        [cell setFrame:cellFrame]; //died once DEAD DEAD DEAD
        [cell setTag:cellFrame.size.height];
        
        NSMutableString* detail = [[NSMutableString alloc] initWithCapacity:100];
        if ([[tweet url] length] > 4)
            [detail appendFormat:@"[%@]", [[tweet url] componentsSeparatedByString:@"\n"]];
        double latitude = [[tweet latitude] doubleValue];
        double longitude = [[tweet longitude] doubleValue];
        if (latitude > -900 && longitude > -900) {
            [detail appendFormat:@"[%0.1lf,%0.1lf]",latitude,longitude];
        } else [cell.imageView setHidden:YES];
        cell.detailTextLabel.text = detail;
        if ([[tweet favorite] boolValue] == YES) {
            [cell.textLabel setTextColor:[UIColor redColor]];
            [cell.detailTextLabel setTextColor:[UIColor redColor]];
        } else if ([[tweet hasBeenRead] boolValue] == YES) {
            [cell.textLabel setTextColor:[UIColor lightGrayColor]];
            [cell.detailTextLabel setTextColor:[UIColor lightGrayColor]];
        } else {
            [cell.textLabel setTextColor:[UIColor blackColor]];
            [cell.detailTextLabel setTextColor:[UIColor blackColor]];
        }
        
        if (latitude > -900 && longitude > -900) {
            [cell.imageView setHidden:NO];
            if ([[tweet url] length] > 4) {
                if ([[tweet locationFromPic] boolValue] == YES)
                    [cell.imageView setImage:self.pinLinkPinImage];
                else
                    [cell.imageView setImage:self.pinLinkImage];
            } else
                [cell.imageView setImage:self.pinImage];
        } else {
            [cell.imageView setHidden:YES];
            [cell.imageView setImage:Nil];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

#pragma mark SCORING SECTION
static NSMutableDictionary* scoring = Nil;
static NSLock* scoringLock = Nil;

- (NSMutableDictionary*)scoringDictionary
{
    if (scoring == Nil) {
        @try {
            if (scoringLock == Nil)
                scoringLock = [[NSLock alloc] init];
            int count = 5;
            while ((![scoringLock tryLock]) && (count > 0)) {
                NSLog(@"BOO BOO cannot lock scoring %d",count);
                [NSThread sleepForTimeInterval:1.0];
                count --;
            }
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"scoring.txt"];
            NSLog(@"READING %@",fileName);
            
            //read the whole file as a single string
            NSData *content = [NSData dataWithContentsOfFile:fileName];
            NSString* jsonString = [[NSString alloc] initWithBytes:[content bytes] length:[content length] encoding:NSUTF8StringEncoding];
            NSLog(@"STRING SCORING: %@",jsonString);
            if (content == Nil) {
                [scoringLock unlock];
                return scoring = [[NSMutableDictionary alloc] initWithCapacity:1];
            } else {
                NSError *jsonError;
                id json = [NSJSONSerialization JSONObjectWithData:content
                                                          options:NSJSONReadingMutableLeaves
                                                            error:&jsonError];
                if (json != Nil) {
                    while (json != Nil && [[json class] isSubclassOfClass:[NSArray class]]) {
                        NSArray* arr = json;
                        if ([arr count] > 0)
                            json = [arr objectAtIndex:0];
                        else
                            json = Nil;
                    }
                    if (json != Nil && [[json class] isSubclassOfClass:[NSDictionary class]]) {
                        scoring = [[NSMutableDictionary alloc] initWithDictionary:json];
                        NSLog(@"SCORING READ: %@",scoring);
                        //[self pruneBookmarks];
                        //NSLog(@"BOOKMARKS READ, after pruning: %@",bookmarks);
                    } else {
                        [scoringLock unlock];
                        return scoring = [[NSMutableDictionary alloc] initWithCapacity:1];
                    }
                }
                else {
                    // inspect the contents of jsonError
                    NSLog(@"GET SCORING JSON err=%@", jsonError);
                    [scoringLock unlock];
                    return scoring = [[NSMutableDictionary alloc] initWithCapacity:1];
                }
            }
            [scoringLock unlock];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            scoring = Nil;
            [scoringLock unlock];
        }
    }
    return scoring;
}
- (void)addScore:(NSInteger)addScore toName:(NSString*)username
{
    @try {
        NSString* scoreKey = username;
        NSNumber* score = [NSNumber numberWithInteger:addScore];
        NSNumber* oldScore = [[self scoringDictionary] objectForKey:scoreKey];
        if (oldScore != Nil)
            score = [NSNumber numberWithInteger:(addScore + [oldScore integerValue])];
        [[self scoringDictionary] setObject:score forKey:scoreKey];
        NSLog(@"*** SCORE%c%d val=%@ key=%@",addScore<0 ? '-' : '+',(int)addScore,score,scoreKey);
        [self saveScores];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        scoring = Nil;
    }
}
- (void)saveScores
{
    @try {
        if (scoringLock == Nil)
            scoringLock = [[NSLock alloc] init];
        if (! [scoringLock tryLock]) {
            NSLog(@"BOO BOO cannot save scoring");
            return;
        }
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"scoring.txt"];
        NSLog(@"WRITING %@",fileName);
        
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        //append text to file (you'll probably want to add a newline every write)
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:[self scoringDictionary] options:NSJSONWritingPrettyPrinted error:nil];
        NSString* jsonString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
        //NSLog(@"SAVING BOOKMARKS: %@", jsonString);
        NSError *error;
        [jsonString writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:&error];
        //NSLog(@"WROTE ERR=%@",error);
        
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        scoring = Nil;
    }
    [scoringLock unlock];
}
- (NSInteger)scoreForUser:(NSString*)username
{
    @try {
        NSNumber* score = [[self scoringDictionary] objectForKey:username];
        return [score integerValue];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
        scoring = Nil;
    }
    return 0;
}

@end

#pragma mark TWEETOPERATION background queue task
@implementation TweetOperation

- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex masterViewController:(TWLocMasterViewController*)theMaster replaceURL:(NSString*)replace
{
    self = [super init];
    executing = finished = NO;
    self->index = theIndex;
    self->tweet = theTweet;
    self->master = theMaster;
    self->replaceURL = replace;
    [self setQueuePriority:NSOperationQueuePriorityVeryLow];
    [TWLocMasterViewController incrementTasks];
    return self;
}

- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)tryImage
{
    // moved this to another operation
    TweetImageOperation* imageOperation = [[TweetImageOperation alloc] initWithTweet:self->tweet
                                                                               index:self->index
                                                                masterViewController:self->master
                                                                          replaceURL:replaceURL];
    [imageOperation setQueuePriority:NSOperationQueuePriorityLow];
    NSOperationQueue* queue = [NSOperationQueue currentQueue];
    [queue addOperation:imageOperation];
}

- (void)main
{
    executing = YES;
    
    @try {
        if ([[tweet hasBeenRead] boolValue] == YES) {
            [TWLocMasterViewController decrementTasks];
            //[[self->master detailViewController] updateTitle];
            executing = NO; finished = YES;
            return;
        }
        NSString* tweetURLmultiple = [tweet url];
        NSEnumerator* urlEnum = [[tweetURLmultiple componentsSeparatedByString:@"\n"] objectEnumerator];
        for (NSString* thisURL = [urlEnum nextObject]; thisURL != Nil && [thisURL length] > 4 ; thisURL = [urlEnum nextObject]) {
            if (replaceURL == Nil &&
                [tweet origHTML] != Nil &&
                [URLProcessor imageExtensionURL:thisURL] == NO) {
                // this must be the first grab, but we've already tried to grab before
                // and it's not an image, so let's just forget it
                continue;
            }
            if (replaceURL == Nil)
                replaceURL = thisURL;
            if ((replaceURL == Nil) ||
                ([replaceURL length] < 4) /*||
                                           ([master imageData:replaceURL] != Nil)*/) {
                                               [TWLocMasterViewController decrementTasks];
                                               //[[self->master detailViewController] updateTitle];
                                               executing = NO; finished = YES;
                                               return;
                                           }
            if ([URLProcessor imageExtensionURL:replaceURL]) {
                [self tryImage];
            } else {
                NSURL* url = [NSURL URLWithString:thisURL];
                NSURLRequest* request = [NSURLRequest requestWithURL:url
                                                         cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                     timeoutInterval:15];
                NSURLResponse* response=nil;
                NSError* error=nil;
                NSData* data=[NSURLConnection sendSynchronousRequest:request
                                                   returningResponse:&response
                                                               error:&error];
                if (data == Nil) {
                    NSLog(@"failed to get %@ in background",thisURL);
                    continue;
                }
                NSMutableString* html = [[NSMutableString alloc] initWithData:data
                                                                     encoding:NSStringEncodingConversionAllowLossy];
                if (html != Nil) {
                    [html appendString:@"\n"];
                    [html appendString:[tweet tweet]];
                    NSMutableArray* urlStrs = [URLProcessor getURLs:html];
                    NSString* replace = [URLProcessor sortURLs:urlStrs fromUrl:thisURL];
                    [html setString:[urlStrs componentsJoinedByString:@"\n\n"]];
                    if ([tweet origHTML] == Nil)
                        [tweet setOrigHTML:html];
                    else
                        [tweet setOrigHTML:[NSString stringWithFormat:@"%@%@", [tweet origHTML], html]];
                    if (replace == Nil)
                        replace = [URLProcessor bestURL:urlStrs forURL:thisURL];
                    if (replace != Nil) {
                        [[master updateQueue] addOperationWithBlock:^{
                            [tweet setUrl:replace];
                        }];
                        NSLog(@"URL_REPLACE %@",replace);
                        replaceURL = replace;
                        if ([URLProcessor imageExtensionURL:replaceURL])
                            [self tryImage];
                        else {
                            TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet
                                                                                  index:index
                                                                   masterViewController:master
                                                                             replaceURL:replaceURL];
                            [top setQueuePriority:NSOperationQueuePriorityLow];
                            [[master multipleOpQueue] addOperation:top];
                            [[master multipleOpQueue] setSuspended:NO];
                        }
                    } else
                        NSLog(@"URL_DEADEND %@ links",replaceURL);
                }
            }
        }
        [[master updateQueue] addOperationWithBlock:^{
            @try {
                NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
                [context processPendingChanges];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
        }];
        
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
    [TWLocMasterViewController decrementTasks];
    [[self->master detailViewController] updateTitle];
    executing = NO; finished = YES;
}

@end

#pragma mark TWEETIMAGEOPERTATION background queue task
@implementation TweetImageOperation

- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex masterViewController:(TWLocMasterViewController*)theMaster replaceURL:(NSString*)replace
{
    self = [super init];
    executing = finished = NO;
    self->index = theIndex;
    self->tweet = theTweet;
    self->master = theMaster;
    self->replaceURL = replace;
    [self setQueuePriority:NSOperationQueuePriorityLow];
    [TWLocMasterViewController incrementTasks];
    return self;
}

- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)tryImage
{
    @try {
        NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:replaceURL]
                                                 cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                             timeoutInterval:30];
        NSURLResponse* response=nil;
        NSError* error=nil;
        NSData* imageData=[NSURLConnection sendSynchronousRequest:request
                                                returningResponse:&response
                                                            error:&error];
        if (imageData == Nil) {
            NSLog(@"BAD IMAGE CONNECTION to %@",replaceURL);
            return;
        } else {
            NSLog(@"background imagedata size %lu %@",(unsigned long)[imageData length],replaceURL);
        }
        
        CGImageSourceRef  source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
        NSDictionary* metadataNew = (__bridge NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,0,NULL);
        
        NSDictionary* gpsInfo = [metadataNew objectForKey:@"{GPS}"];
        id latitude = [gpsInfo objectForKey:@"Latitude"];
        id latitudeRef = [gpsInfo objectForKey:@"LatitudeRef"];
        id longitude = [gpsInfo objectForKey:@"Longitude"];
        id longitudeRef = [gpsInfo objectForKey:@"LongitudeRef"];
        float lat = -1000;
        float lon = -1000;
        if (latitude != Nil && latitudeRef != Nil &&
            longitude != Nil && longitudeRef != Nil) {
            lat = [(NSNumber*)latitude floatValue];
            if ([(NSString*)latitudeRef compare:@"S"] == NSOrderedSame)
                lat = 0-lat;
            lon = [(NSNumber*)longitude floatValue];
            if ([(NSString*)longitudeRef compare:@"W"] == NSOrderedSame)
                lon = 0-lon;
        }
        if (lat > -900 && lon > -900) {
            [[master updateQueue] addOperationWithBlock:^{
                [tweet setLocationFromPic:[NSNumber numberWithBool:YES]];
                [tweet setLatitude:[NSNumber numberWithDouble:lat]];
                [tweet setLongitude:[NSNumber numberWithDouble:lon]];
                NSLog(@" @ %0.1f,%01f",lat,lon);
                if (index == Nil)
                    index = [master.fetchedResultsController indexPathForObject:tweet];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
                }];
            }];
        }
        [master imageData:imageData forURL:replaceURL];
        
        __block bool hasVideo = NO;
        [[URLProcessor getURLs:[tweet origHTML]] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString* theURL = obj;
            if ([URLProcessor isVideoFileURL:theURL]){
                hasVideo = *stop = YES;
            }
        }];
        NSInteger score = -1;
        CGSize size = [[UIImage imageWithData:imageData] size];
        if (size.height > 900) score +=5;
        if (size.width > 900) score += 5;
        if (lat > -900 && lon > -900) score += 100;
        if (hasVideo) score += 25;
        [self->master addScore:score toName:[tweet username]];
        int picSize = MAX(size.height, size.width);
        if ([PhotoGetter isGIFtype:replaceURL])
            picSize *= 2;
        if (lat > -900 && lon > -900) picSize += 5000;
        if (hasVideo) picSize += 500;
        [tweet setHasPicSize:[NSNumber numberWithInt:picSize]];
        [tweet setUserScore:[NSNumber numberWithInteger:[self->master scoreForUser:[tweet username]]]];
        [[master updateQueue] addOperationWithBlock:^{
            [[master.fetchedResultsController managedObjectContext] processPendingChanges];
            [[master tableView] reloadData];
        }];
        
        if ([[[master detailViewController] class] isSubclassOfClass:[TWLocCollectionViewController class]])
        {
            TWLocCollectionViewController* colView = (TWLocCollectionViewController*)[master detailViewController];
            TWLocPicCollectionCell* cell = (TWLocPicCollectionCell*)[[colView collectionView] cellForItemAtIndexPath:index];
            UIImage* image = [UIImage imageWithData:imageData];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [[cell theImage] setImage:image];
            }];
        }
        
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
}

- (void)main
{
    executing = YES;
    
    @try {
        if ([[tweet hasBeenRead] boolValue] == YES) {
            [TWLocMasterViewController decrementTasks];
            //[[self->master detailViewController] updateTitle];
            executing = NO; finished = YES;
            return;
        }
        if (replaceURL == Nil)
            replaceURL = [[[tweet url] componentsSeparatedByString:@"\n"] firstObject];
        if ((replaceURL == Nil) ||
            ([replaceURL length] < 4) ||
            ([master imageData:replaceURL] != Nil) ) {
            [TWLocMasterViewController decrementTasks];
            //[[self->master detailViewController] updateTitle];
            executing = NO; finished = YES;
            return;
        }
        if ([URLProcessor imageExtensionURL:replaceURL]) {
            if ([master imageData:replaceURL] == Nil)
                [self tryImage];
        }
        
        [[master updateQueue] addOperationWithBlock:^{
            @try {
                NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
                [context processPendingChanges];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [NSThread callStackSymbols]);
    }
    
    [TWLocMasterViewController decrementTasks];
    [[self->master detailViewController] updateTitle];
    executing = NO; finished = YES;
}

@end

#pragma mark GETTWEETOPERATION background queue task
@implementation GetTweetOperation

- (id)initWithMaster:(TWLocMasterViewController*)theMaster andList:(NSNumber*)theListID
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    listID = theListID;
    [self setQueuePriority:NSOperationQueuePriorityLow];
    [TWLocMasterViewController incrementTasks];
    return self;
}

- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    [master getTweets:listID];
    [TWLocMasterViewController decrementTasks];
    [[self->master detailViewController] updateTitle];
    executing = NO; finished = YES;
}

@end

#pragma mark STORETWEETOPERATION background queue task
@implementation StoreTweetOperation

- (id)initWithMaster:(TWLocMasterViewController*)theMaster timeline:(NSArray*)theTimeline andList:(NSNumber*)theListID
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    listID = theListID;
    timeline = theTimeline;
    [self setQueuePriority:NSOperationQueuePriorityLow];
    [TWLocMasterViewController incrementTasks];
    return self;
}
- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    [master storeTweets:timeline andList:listID];
    if ([[[master detailViewController] class] isSubclassOfClass:[TWLocCollectionViewController class]])
    {
        TWLocCollectionViewController* colView = (TWLocCollectionViewController*)[master detailViewController];
        if ([timeline count] > 0) {
            [[colView collectionView] reloadData];
        }
    }
    [TWLocMasterViewController decrementTasks];
    [[self->master detailViewController] updateTitle];
    executing = NO; finished = YES;
}


@end


