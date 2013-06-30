//
//  TWLocMasterViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocMasterViewController.h"
#import "TWLocDetailViewController.h"
#import "Image.h"
#import "Tweet.h"
#import "URLFetcher.h"
#import "GoogleReader.h"

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

#define ALERT_DUMMY (1)
#define ALERT_NOTWITTER (666)
#define ALERT_SELECTACCOUNT (1776)
#define ALERT_SETALLREAD (1999)
#define ALERT_GOOGLE (0xdead)
#define ALERT_REFRESH (2001)

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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

static bool NetworkAccessAllowed = NO;
+ (void)setNetworkAccessAllowed:(BOOL)allowed {NetworkAccessAllowed = allowed;}

// will get hit when the user chooses a URL from the text view
// should load the image
-(BOOL)openURL:(NSURL *)url
{
    if (self.detailViewController != Nil)
        return [self.detailViewController openURL:url];
    return NO;
}

- (void)killMax {
    _twitterIDMax = _twitterIDMin = -1;
    self->maxIDEachList = [[NSMutableDictionary alloc] initWithCapacity:1];
    [self->maxIDEachList setObject:[NSNumber numberWithLongLong:-1] forKey:[NSNumber numberWithLongLong:0]];
}

static int numImages = 0;
- (TWIMAGE*)getImageServer
{
    if (self->imageServer == Nil) {
#if (TWIMAGE != TMCache)
        self->imageServer = [[TWIMAGE alloc] init];
        [self->imageServer setMasterViewController:self];
#else
        self->imageServer = [[TMCache alloc] initWithName:@"ImageFile"];
        if (self->imageServer != Nil) {
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
#endif
    }
    return self->imageServer;
}

- (NSData*)imageData:(NSString*)url
{
    @try {
#if (TWIMAGE != TMCache)
        return [[self getImageServer] imageData:url];
#else
        return [[self getImageServer] objectForKey:url];
#endif
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return Nil;
}
- (void)deleteImageData:(NSString*)url
{
    @try {
#if (TWIMAGE != TMCache)
        [[self getImageServer] deleteImageData:url];
#else
        if (url != Nil) {
            [[self getImageServer] objectForKey:url block:^(TMCache *cache, NSString *key, id object) {
                if (object != Nil && key != Nil && [key length] > 0) {
                    [[self getImageServer] removeObjectForKey:url];
                    numImages--;
                }
            }];
        } else {
            [[self getImageServer] removeAllObjects:^(TMCache *cache) {
                NSLog(@"removed everything setting images to 0");
                numImages = 0;
                [self checkToSeeIfAllDeleted];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE COMPLETE" message:@"All images have been deleted from the local store." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
                    [alert show];
                }];
            }];
        }
#endif
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)imageData:(NSData*)data forURL:(NSString*)url
{
    @try {
#if (TWIMAGE != TMCache)
        [[self getImageServer] imageData:data forURL:url];
#else
        [[self getImageServer] setObject:data forKey:url];
        numImages++;
#endif
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)backgroundImageData:(NSData *)data forURL:(NSString *)url
{
    @try {
#if (TWIMAGE != TMCache)
        [[self getImageServer] imageData:data forURL:url];
#else
        [[self getImageServer] setObject:data forKey:url block:^(TMCache *cache, NSString *key, id object) {
            NSLog(@"Stored %d image %@",[data length],url);
            numImages++;
        }];
#endif
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (long long)sizeImages
{
#if (TWIMAGE != TMCache)
    return [[self getImageServer] sizeImages];
#else
    return [[self getImageServer] diskByteCount];
#endif
}
- (int)numImages
{
    return numImages;
}

- (void)checkToSeeIfAllDeleted
{
    NSURL* directory = [[[self getImageServer] diskCache] cacheURL];
    NSFileManager* fManager = [NSFileManager defaultManager];
    NSArray* files = [fManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:Nil options:0 error:Nil];
    if ([files count] > 1) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"DELETE FAILED" message:[NSString stringWithFormat:@"%d file images still remain in the local store.",[files count]] delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
            [alert show];
        }];
    }
}

#pragma mark URL_WORKER
static NSMutableArray* urlQueue = Nil;
- (void)keepTrackofReadURLs:(NSString*)url
{
    @try {
        if (!urlQueue)
            urlQueue = [[NSMutableArray alloc] initWithCapacity:5];
        if (urlQueue ) {
            __block bool found = NO;
            [urlQueue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString* e = obj;
                if ([e isEqualToString:url])
                    found = *stop = YES;
            }];
            if (found) {
                NSLog(@"upending %@",url);
                [urlQueue removeObject:url];
                [urlQueue addObject:url];
                return;
            }
            [urlQueue addObject:url];
            if ([urlQueue count] < 20)
                return;
            int urlCount = [urlQueue count];
            
            __block NSString* deleteURL = [urlQueue objectAtIndex:0];
            [urlQueue removeObjectAtIndex:0];
            [_webQueue addOperationWithBlock:^{
                NSLog(@"Deleting image %d %@",urlCount,deleteURL);
                [self deleteImageData:deleteURL];
            }];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)dropReadURLs:(MasterCallback)callback
{
    @try {
        if (!urlQueue)
            return;
        [_webQueue addOperationWithBlock:^{
            [urlQueue enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString* deleteURL = obj;
                NSLog(@"Deleting image %@",deleteURL);
                [self deleteImageData:deleteURL];
            }];
            [urlQueue removeAllObjects];
            if (callback != Nil)
                callback();
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (NSIndexPath*)nextIndex:(NSIndexPath*)index forTable:(UITableView*)table
{
    int numRows = [self.tableView numberOfRowsInSection:index.section];
    int numSections = [self.tableView numberOfSections];
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
        NSIndexPath* nextindex = [self nextIndex:selected forTable:self.tableView];
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
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)nextNewTweet
{
    @try {
        NSLog(@"NEXT New TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        NSIndexPath* nextindex = [self nextIndex:selected forTable:self.tableView];
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
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        @try {
            [self.tableView selectRowAtIndexPath:nextindex
                                        animated:YES
                                  scrollPosition:UITableViewScrollPositionMiddle];
            Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
            self.detailViewController.detailItem = object;
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)deleteTweet:(Tweet*)tweet
{
    NSLog(@"want to delete tweet %@",[tweet tweetID]);
    @try {
        NSLog(@"NEXT TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        int numRows = [self.tableView numberOfRowsInSection:selected.section];
        int offset=0;
        if (selected.row+1 >= numRows)
            offset = -1;

        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        @try {
            [context deleteObject:tweet];
            [context processPendingChanges];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            NSArray* urls = [TWLocDetailViewController staticGetURLs:[tweet tweet]];
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)favoriteTweet:(Tweet*)tweet
{
    NSLog(@"want to FAV tweet %@",[tweet tweetID]);
    if (self->twitterAccount == Nil)
        return;
    @try {
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:[[tweet tweetID] description] forKey:@"id"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/favorites/create.json"];
        
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        //  Build the request with our parameter
        TWRequest *request =[[TWRequest alloc] initWithURL:url
                                                parameters:params
                                             requestMethod:TWRequestMethodPOST];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
        
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
                             NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
                         }
                     }];
                 }];
             }];
             UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"FAVORITEd" message:@"Tweet was favorited." delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
             [alert setTag:ALERT_DUMMY];
             [alert show];
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

- (void)queueTweetGet:(NSNumber*)listID
{
    @try {
        if (_theQueue) {
            if ([[self.detailViewController activityLabel] isHidden]) {
                [UIView animateWithDuration:0.4 animations:^{
                    [self.detailViewController activityLabel].hidden = NO;
                }];
                [[self.detailViewController activityLabel] setText:@"Getting Tweets:"];
            }

            _maxTweetsToGet = NUMTWEETSTOGET;
            _twitterIDMax = -1;
            _twitterIDMin = -1;
            
            if (listID == Nil) {
                NSDictionary* listNames = self->lists;
                [[[listNames keyEnumerator] allObjects] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    NSNumber* listID = [self->lists objectForKey:(NSString*)obj];
                    NSLog(@"adding list %@ to the getQueue",listID);
                    [self->queueGetArray addObject:listID];
                }];
                
                if ([self.fetchedResultsController fetchedObjects] != Nil) {
                    NSLog(@"queue FETCH is %d tweets",[[self.fetchedResultsController fetchedObjects] count]);
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
            if (_twitterIDMax == -1)
                _twitterIDMax = [self getMaxTweetID:Nil];
            
            _nextIDMax = _twitterIDMax;
            if (listID == Nil)
                [self deleteTweetDataFile];
            GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self andList:listID];
            [_webQueue setSuspended:NO];
            [TWLocMasterViewController incrementTasks];
            [_webQueue addOperation:getTweetOp];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            
            [self getTwitterLists];
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

#pragma mark Alerts

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    @try {
        if ([alertView tag] == ALERT_NOTWITTER) {
            // not allowed to exit
            NSLog(@"No twitter accounts.  I'm going to sit and stew.");
            if (_googleReaderLibrary) {
                GoogleOperation* googleOp = [[GoogleOperation alloc] initWithMaster:self rssFeed:Nil orSubscriptions:Nil andStream:Nil];
                [TWLocMasterViewController incrementTasks];
                [_webQueue addOperation:googleOp];
                [_webQueue setSuspended:NO];
            }
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
                
                [self getTwitterLists];
            }
        }
        if ([alertView tag] == ALERT_SETALLREAD) {
            NSString* buttonNameHit = [alertView buttonTitleAtIndex:buttonIndex];
            if ([buttonNameHit isEqualToString:@"CANCEL"])
                NSLog(@"don't set all to read");
            else if ([buttonNameHit isEqualToString:@"TWEETS READ"]) {
                NSLog(@"YES set all to read");
                [self allTweetsNeedToBeSetToRead];
            } else if ([buttonNameHit isEqualToString:@"DELETE IMAGES"]) {
                NSLog(@"deleting all images");
                [_theQueue addOperationWithBlock:^{
                    [self deleteImageData:Nil]; // removes all image data
                }];
            }
        }
        if ([alertView tag] == ALERT_REFRESH) {
            NSString* buttonNameHit = [alertView buttonTitleAtIndex:buttonIndex];
            if ([buttonNameHit isEqualToString:@"Twitter"]) {
                [self refreshTweets:Nil];
            } else if ([buttonNameHit isEqualToString:@"Google"]) {
                if ([[self.detailViewController activityLabel] isHidden]) {
                    [UIView animateWithDuration:0.4 animations:^{
                        [self.detailViewController activityLabel].hidden = NO;
                    }];
                    [[self.detailViewController activityLabel] setText:@"Getting Google Items:"];
                }
                GoogleOperation* googleOp = [[GoogleOperation alloc] initWithMaster:self rssFeed:Nil orSubscriptions:Nil andStream:Nil];
                [TWLocMasterViewController incrementTasks];
                [_webQueue addOperation:googleOp];
                [_webQueue setSuspended:NO];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

#pragma mark Tweets
#define MAXTWEETS (500)
#define TWEETREQUESTSIZE (200)

- (void)getTweets:(NSNumber*)listID
{
    if (self->twitterAccount == Nil)
        return;
    
    @try {
        
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
            [params setObject:requestSize forKey:@"count"];
            [params setObject:[listID stringValue] forKey:@"list_id"];
        } else
            [params setObject:requestSize forKey:@"count"];
        if (_twitterIDMax > 0)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMax] forKey:@"since_id"];
        if (_twitterIDMin > 0 && _twitterIDMin != _twitterIDMax)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMin] forKey:@"max_id"];
        NSLog(@"getting tweets max=%lld min=%lld", _twitterIDMax, _twitterIDMin);
        
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        //  Build the request with our parameter
        TWRequest *request =[[TWRequest alloc] initWithURL:url
                                                parameters:params
                                             requestMethod:TWRequestMethodGET];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
        
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
                     [self saveTweetDebugToFile:[NSString stringWithFormat:@"received %d tweets\n", [timeline count]]];
                     [self saveTweetDataToFile:responseData];

                     if (_theQueue != Nil) {
                         NSLog(@"adding storetweet size=%d to the Queue", [timeline count]);
                         StoreTweetOperation* storeTweetOp = [[StoreTweetOperation alloc] initWithMaster:self timeline:timeline andList:listID];
                         [_updateQueue setSuspended:NO];
                         [TWLocMasterViewController incrementTasks];
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)storeTweets:(NSArray*)timeline andList:(NSNumber*)theListID
{
    @try {
        int storedTweets = 0;
        __block BOOL twitterErrorDetected = NO;
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
        
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
        
        NSLog(@"storing %d tweets",[timeline count]);
        while ((item = [e nextObject]) != Nil &&
               [[item class] isSubclassOfClass:[NSDictionary class]]) {
            @try {
                NSString* theUrl = @"";
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
                        NSDictionary* urls = [urlsArray lastObject];
                        if (urls != Nil) {
                            theUrl = [urls objectForKey:@"expanded_url"];
                            //NSLog(@"   url=%@",theUrl);
                        }
                        if (urls == Nil || theUrl == Nil)
                            NSLog(@"bad last urls item in %@ ???",[urlsArray componentsJoinedByString:@" , "]);
                    }
                    NSArray* media = [entities objectForKey:@"media"];
                    if (media != Nil && [media count] > 0) {
                        if ([media count] > 1)
                            NSLog(@"multiple media items %@",[media componentsJoinedByString:@" , "]);
                        NSDictionary* mediaItem = [media lastObject];
                        if (mediaItem != Nil) {
                            NSString* anotherURL = [mediaItem objectForKey:@"media_url"];
                            if (anotherURL != Nil && [anotherURL length] > 4) {
                                theUrl = anotherURL;
                                //NSLog(@"   url=%@",theUrl);
                            }
                        }
                        if (mediaItem == Nil || theUrl == Nil)
                            NSLog(@"bad last media item in %@ ???",[media componentsJoinedByString:@" , "]);
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
                    if (![theUrl respondsToSelector:@selector(rangeOfString:)])
                        theUrl = @"";
                    else if ([theUrl rangeOfString:@"/4sq.com/"].location != NSNotFound)
                        theUrl = @"";
                    else if ([theUrl rangeOfString:@"/huff.to/"].location != NSNotFound)
                        theUrl = @"";
                    else if ([theUrl length] > 4) {
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
                        [tweet setUrl:theUrl];
                        [tweet setOrigURL:theUrl];
                        [tweet setOrigHTML:Nil];
                        [tweet setLocationFromPic:[NSNumber numberWithBool:NO]];
                        [tweet setHasBeenRead:[NSNumber numberWithBool:NO]];
                        if (theListID != Nil)
                            [tweet setListID:theListID];
                        else
                            [tweet setListID:[NSNumber numberWithLongLong:0]];
                        [tweet setFromGoogleReader:[NSNumber numberWithBool:YES]];
                        [tweet setGoogleID:Nil];
                        [tweet setGoogleStream:Nil];
                        
                        [_idSet addObject:theID];
                        storedTweets++;
                    }
                    [self saveTweetDebugToFile:[NSString stringWithFormat:@"original tweet %@\n",theID]];
                } else {
                    [self saveTweetDebugToFile:[NSString stringWithFormat:@"DUP      tweet %@\n",theID]];
                }
                
            } @catch (NSException* eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }
        NSString* blurb = [NSString stringWithFormat:@"Done storing %d tweets (%d real tweets)",[timeline count], storedTweets];
        NSLog(@"%@",blurb);
        [self saveTweetDebugToFile:blurb];
        
        _maxTweetsToGet -= [timeline count];
        NSLog(@"got %d tweets, %lld more to get", [timeline count], _maxTweetsToGet);        
        [_updateQueue addOperationWithBlock:^{
            NSString* listname = @"TIMELINE";
            if (theListID != Nil) {
                NSArray* keys = [self->lists allKeysForObject:theListID];
                if (keys != Nil && [keys count] > 0)
                    listname = [keys objectAtIndex:0];
            }
            NSString* status = [[self.detailViewController activityLabel] text];
            [[self.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\nRetrieved %d new (%d old) tweets from the %@ area",status,storedTweets,[timeline count]-storedTweets,listname]];
            status = [NSString stringWithFormat:@"Storing %@ tweets [%d]",listname, storedTweets];
            [self STATUS:status];
        }];
        
        if (_theQueue != Nil && storedTweets > 0 &&
            !([timeline count] < (TWEETREQUESTSIZE/2) || _maxTweetsToGet < 1)) {
            NSLog(@"adding another getTweet to the Queue");

            GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self andList:theListID];
            [_webQueue setSuspended:NO];
            [TWLocMasterViewController incrementTasks];
            [_webQueue addOperation:getTweetOp];
        } else {
            if (_nextIDMax > 0)
                _twitterIDMax = _nextIDMax;
            else
                [self saveTweetDebugToFile:[NSString stringWithFormat:@"did not get a new twitterIDMax\n"]];
            [self saveTweetDebugToFile:[NSString stringWithFormat:@"new twitterIDMax %lld\n",_twitterIDMax]];
            NSLog(@"new TwitterIDMax %lld",_twitterIDMax);
            [_updateQueue addOperationWithBlock:^{
                [self STATUS:[NSString stringWithFormat:@"%d tweets: %d images %0.2fMB",[_idSet count],[self numImages], [self sizeImages]/1024.0/1024.0]];
            }];

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
                        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
                            if (_theQueue != Nil && NetworkAccessAllowed &&
                                [[tweet hasBeenRead] boolValue] == NO) {
                                NSIndexPath* indexPath = [self.fetchedResultsController indexPathForObject:tweet];
                                if (indexPath != Nil) {
                                    TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet
                                                                                          index:indexPath
                                                                           masterViewController:self
                                                                                     replaceURL:Nil];
                                    [TWLocMasterViewController incrementTasks];
                                    [_webQueue addOperation:top];
                                    [_webQueue setSuspended:NO];
                                }
                            }
                        }
                    } @catch (NSException *eee) {
                        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
                    }
                    NSString* status = [[self.detailViewController activityLabel] text];
                    [[self.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\nNote: currently storing %d images, of size %0.2fMB",status,[self numImages], [self sizeImages]/1024.0/1024.0]];
                }];
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (NSDictionary*)getTwitterLists
{
    NSMutableDictionary* returnDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    if (self->twitterAccount == Nil)
        return returnDict;
    
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:@"1" forKey:@"include_entities"];
        if (_twitterIDMax > 0)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMax] forKey:@"since_id"];
        [params setObject:@"50" forKey:@"count"];
        if (_twitterIDMin > 0 && _twitterIDMin != _twitterIDMax)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",_twitterIDMin] forKey:@"max_id"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"http://api.twitter.com/1.1/lists/list.json"];
        
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        //  Build the request with our parameter
        TWRequest *request =[[TWRequest alloc] initWithURL:url
                                                parameters:params
                                             requestMethod:TWRequestMethodGET];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        NSLog(@"getting tweets max=%lld min=%lld", _twitterIDMax, _twitterIDMin);
        [self saveTweetDebugToFile:[NSString stringWithFormat:@"****************\ngetting tweets max=%lld min=%lld\n", _twitterIDMax, _twitterIDMin]];
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
                             }
                         } @catch (NSException *eee) {
                             NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
                         }
                     }];
             }
             self->lists = returnDict;
             [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                 [self queueTweetGet:Nil];
             }];
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return returnDict;
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"All Done?" message:@"Set all tweets to READ, or delete images?" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"TWEETS READ", @"DELETE IMAGES", nil];
    [alert setTag:ALERT_SETALLREAD];
    [alert show];
    return; // don't delete, don't set things to "read" state
}
- (void)allTweetsNeedToBeSetToRead
{
    @try {
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
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
            Tweet* tweet = Nil;
            NSEnumerator* e = [results objectEnumerator];
            while ((tweet = [e nextObject]) != Nil) {
                if ([[tweet hasBeenRead] boolValue] == NO) {
                    [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
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
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ALL SET TO READ" message:@"All tweets have been set to READ" delegate:Nil cancelButtonTitle:@"OKAY" otherButtonTitles: nil];
            [alert setTag:ALERT_DUMMY];
            [alert show];
         }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Twitter or Google?" message:@"grab twitter, or google?" delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"Twitter", @"Google", nil];
            [alert setTag:ALERT_REFRESH];
            [alert show];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            [self getTwitterLists];
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
                int rows = [section numberOfObjects];
                NSLog(@"sections=%d row[0]=%d",[sections count],rows);
                if (rows > MAXTWEETS) {
                    NSLog(@"More than %d tweets in section %@, going to remove some", MAXTWEETS, [section name]);
                    for (int i = rows-1; i > MAXTWEETS; i--) {
                        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:i inSection:sect];
                        Tweet *tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
                        bool deleteMe = [[tweet hasBeenRead] boolValue];
                        if (i < MAXTWEETS+100) {
                            if ([[tweet locationFromPic] boolValue] == YES)
                                deleteMe = NO;
                            if ([[tweet favorite] boolValue] == YES)
                                deleteMe = NO;
                        }
                        if (deleteMe) {
                            //NSLog(@"removing %d tweet %@",i,tweet);
                            __block NSString* url = [tweet url];
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    
    [_updateQueue addOperationWithBlock:^{
        @try {
            NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
            [context processPendingChanges];
            [self.tableView reloadData];
            NSString* status = [[NSString alloc] initWithFormat: @"Tweet Count = %d", [_idSet count]];
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
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

#pragma mark autogenerated

- (void)awakeFromNib
{
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
    [super viewDidLoad];
    
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
    self.detailViewController = (TWLocDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
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
    _webQueue = [[NSOperationQueue alloc] init];
    [_webQueue setMaxConcurrentOperationCount:5];
    _theQueue = [[NSOperationQueue alloc] init];
    [_theQueue setMaxConcurrentOperationCount:1];
    _theOtherQueue = Nil;
    
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
    _googleReaderLibrary = YES;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber* thing = [defaults objectForKey:@"googleLibrary"];
    NSLog(@"googleLibrary is %@",thing);
    _googleReaderLibrary = [thing boolValue];
    _googleReader = [[GoogleReader alloc] init];
    
    if (_tweetLibrary) {
        self->twitterAccount = Nil;
        self->twitterAccountName = [defaults objectForKey:@"twitterAccount"];
        _twitterIDMax = -1;
        _nextIDMax = _twitterIDMax;
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
-(void)stopBackgroundTaskHolder {
    NSLog(@"STOPPING BACKGROUND TASK %d", backgroundTaskNumber);
    if (backgroundTaskNumber != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskNumber];
        backgroundTaskNumber = UIBackgroundTaskInvalid;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self saveContext];
        }];
    }
}
-(void)beginBackgroundTaskHolder {
    backgroundTaskNumber = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self stopBackgroundTaskHolder];
        [self beginBackgroundTaskHolder];
    }];
    NSLog(@"STARTING BACKGROUND TASK %d", backgroundTaskNumber);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    @try {
        NSLog(@"MEMORY WARNING in master view");
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return unreadReturn;
}

#pragma mark - Fetched results controller
- (void)saveContext
{
#if (TWIMAGE != TMCache)
    return [[self getImageServer] saveContext];
#else
    
#endif
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
            //NSSortDescriptor *sortDescriptorUsername = [[NSSortDescriptor alloc] initWithKey:@"username" ascending:YES selector:@selector(caseInsensitiveCompare:)];
            //NSSortDescriptor *sortDescriptorhasGPS = [[NSSortDescriptor alloc] initWithKey:@"locationFromPic" ascending:NO];
            //NSSortDescriptor *sortDescriptorFavorite = [[NSSortDescriptor alloc] initWithKey:@"favorite" ascending:NO];
            NSSortDescriptor *sortDescriptorID = [[NSSortDescriptor alloc] initWithKey:@"tweetID" ascending:NO];
            NSArray *sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptorID, nil];
            
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
                NSLog(@"Initital FETCH is %d tweets",[[self.fetchedResultsController fetchedObjects] count]);
                [self saveTweetDebugToFile:[NSString stringWithFormat:@"Initital FETCH is %d tweets\n",[[self.fetchedResultsController fetchedObjects] count]]];
                NSEnumerator* e = [[self.fetchedResultsController fetchedObjects] objectEnumerator];
                Tweet* tweet;
                while ((tweet = [e nextObject]) != Nil) {
                    [_idSet addObject:[tweet tweetID]];
                }
                NSLog(@"done setting up the ID array");
            } else NSLog(@"NO TWEETS FETCHED! IS THE DB EMPTY?");
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
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
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

- (void)cellSetup:(UITableViewCell *)cell forTweet:(Tweet*)tweet
{
    if (cell == Nil || tweet == Nil)
        return;
    
    @try {
        cell.textLabel.text = [[NSString alloc] initWithFormat:@"[%@]:%@",
                               [tweet username], [tweet tweet] ];
        //UIFont* font = [[cell textLabel] font];
        //CGSize descriptionHeight = [cell.textLabel.text sizeWithFont:font constrainedToSize:[cell textLabel].frame.size lineBreakMode:[[cell textLabel] lineBreakMode]];
        //CGRect frame = [cell.textLabel frame];
        //frame.size.height = descriptionHeight.height;
        //[cell.textLabel setFrame:frame];
        //CGRect detailFrame = [cell.detailTextLabel frame];
        //detailFrame.origin.y = frame.size.height + frame.origin.y * 2;
        //[cell.detailTextLabel setFrame:detailFrame];
        //CGRect cellFrame = [cell frame];
        //cellFrame.size.height = detailFrame.origin.y + detailFrame.size.height;
        //[cell setFrame:cellFrame]; //died once DEAD DEAD DEAD
        //[cell setTag:cellFrame.size.height];
        
        NSMutableString* detail = [[NSMutableString alloc] initWithCapacity:100];
        if ([[tweet url] length] > 4)
            [detail appendFormat:@"[%@]", [tweet url]];
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
            /*NSData* data = [self imageData:[tweet url]];
             if (data != Nil)
             [cell.imageView setImage:[UIImage imageWithData:data]];
             else
             [cell.imageView setImage:self.redX];*/
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
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
    [TWLocMasterViewController incrementTasks];
    [queue addOperation:imageOperation];
}

- (void)main
{
    executing = YES;
    
    @try {
        if ([[tweet hasBeenRead] boolValue] == YES) {
            [TWLocMasterViewController decrementTasks];
            executing = NO; finished = YES;
            return;
        }
        if (replaceURL == Nil &&
                 [tweet origHTML] != Nil &&
            [TWLocDetailViewController imageExtension:[tweet url]] == NO) {
            // this must be the first grab, but we've already tried to grab before
            // and it's not an image, so let's just forget it
            [TWLocMasterViewController decrementTasks];
            executing = NO; finished = YES;
            return;
        }
        if (replaceURL == Nil)
            replaceURL = [tweet url];
        if ((replaceURL == Nil) ||
            ([replaceURL length] < 4) ||
            ([master imageData:replaceURL] != Nil)) {
            [TWLocMasterViewController decrementTasks];
            executing = NO; finished = YES;
            return;
        }
        if ([TWLocDetailViewController imageExtension:replaceURL]) {
            [self tryImage];
        } else {
            NSURL* url = [NSURL URLWithString:[tweet url]];
            NSURLRequest* request = [NSURLRequest requestWithURL:url
                                                     cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                 timeoutInterval:15];
            NSURLResponse* response=nil;
            NSError* error=nil;
            NSData* data=[NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&response
                                                           error:&error];
            if (data == Nil) {
                NSLog(@"failed to get %@ in background",[tweet url]);
                [TWLocMasterViewController decrementTasks];
                executing = NO; finished = YES;
                return;
            }
            NSMutableString* html = [[NSMutableString alloc] initWithData:data
                                                                 encoding:NSStringEncodingConversionAllowLossy];
            if (html != Nil) {
                [html appendString:@"\n"];
                [html appendString:[tweet tweet]];
                NSString* replace = [TWLocDetailViewController staticFindJPG:html theUrlStr:[tweet url]];
                if ([tweet origHTML] == Nil ||
                    [replaceURL rangeOfString:@"photoset_iframe"].location != NSNotFound) {
                    [[master updateQueue] addOperationWithBlock:^{
                        [tweet setOrigHTML:html];
                    }];
                }
                if (replace != Nil) {
                    [[master updateQueue] addOperationWithBlock:^{
                        [tweet setUrl:replace];
                    }];
                    NSLog(@"URL_REPLACE %@",replace);
                    replaceURL = replace;
                    if ([TWLocDetailViewController imageExtension:replaceURL])
                        [self tryImage];
                    else {
                        TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet
                                                                              index:index
                                                               masterViewController:master
                                                                         replaceURL:replaceURL];
                        [top setQueuePriority:NSOperationQueuePriorityLow];
                        [TWLocMasterViewController incrementTasks];
                        [[master webQueue] addOperation:top];
                        [[master webQueue] setSuspended:NO];
                    }
                    //[[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    //    [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
                    //}];
                } else
                    NSLog(@"URL_DEADEND %@ links",replaceURL);
            }
        }
        
        [[master updateQueue] addOperationWithBlock:^{
            @try {
                NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
                [context processPendingChanges];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

    [TWLocMasterViewController decrementTasks];
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
            NSLog(@"background imagedata size %d %@",[imageData length],replaceURL);
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
                [[master.fetchedResultsController managedObjectContext] processPendingChanges];
            }];
        }
        [master imageData:imageData forURL:replaceURL];

    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)main
{
    executing = YES;
    
    @try {
        if ([[tweet hasBeenRead] boolValue] == YES) {
            [TWLocMasterViewController decrementTasks];
            executing = NO; finished = YES;
            return;
        }
        if (replaceURL == Nil)
            replaceURL = [tweet url];
        if ((replaceURL == Nil) ||
            ([replaceURL length] < 4) ||
            ([master imageData:replaceURL] != Nil) ) {
            [TWLocMasterViewController decrementTasks];
            executing = NO; finished = YES;
            return;
        }
        if ([TWLocDetailViewController imageExtension:replaceURL]) {
            [self tryImage];
            //[[NSOperationQueue mainQueue] addOperationWithBlock:^{
            //    [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
            //}];
        }
        
        [[master updateQueue] addOperationWithBlock:^{
            @try {
                NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
                [context processPendingChanges];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    
    [TWLocMasterViewController decrementTasks];
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
    return self;
}
- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    [master storeTweets:timeline andList:listID];
    [TWLocMasterViewController decrementTasks];
    executing = NO; finished = YES;
}


@end

#pragma mark GOOGLEOPERATION background queue task
@implementation GoogleOperation

- (id)initWithMaster:(TWLocMasterViewController*)theMaster rssFeed:(NSArray*)theFeed orSubscriptions:(NSArray*)theSubscriptions andStream:(NSString*)theStreamName
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    rssFeed = theFeed;
    subscriptions = theSubscriptions;
    subscriptionName = Nil;
    streamName = theStreamName;
    [self setQueuePriority:NSOperationQueuePriorityLow];
    return self;
}
- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

int googleAddedItems = 0;

- (void)main
{
    executing = YES;

    if (rssFeed != Nil) {
        // handle the rss contents if there are any
    } else if (subscriptions != Nil) {
        // queue grabbing the subscription contents
        if ([[subscriptions class] isSubclassOfClass:[NSArray class]]) {
            @try {
                NSEnumerator* e = [subscriptions objectEnumerator];
                NSDictionary* subscription = Nil;
                tweetsToProcess = [[NSMutableArray alloc] initWithCapacity:100];
                while ((subscription = [e nextObject]) != Nil &&
                       [tweetsToProcess count] < 100) {
                    subscriptionName = [subscription objectForKey:@"title"];
                    [self getItems:[subscription objectForKey:@"id"]];
                }
                NSString* stat = [NSString stringWithFormat:@"Have retrieved %d Google items",[tweetsToProcess count]];
                [[master updateQueue] addOperationWithBlock:^{
                    NSString* status = [[master.detailViewController activityLabel] text];
                    [[master.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\n%@",status,stat]];
                    [master STATUS:stat];
                }];
                // TODO: need to sort the processing top-to-bottom
                NSLog(@"sorting the new items");
                [tweetsToProcess sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    Tweet* t1 = obj1;
                    Tweet* t2 = obj2;
                    long long a1 = [[t1 tweetID] longLongValue];
                    long long a2 = [[t2 tweetID] longLongValue];
                    if (a1 > a2) return NSOrderedAscending;
                    if (a1 == a2) return NSOrderedSame;
                    return NSOrderedDescending;
                }];
                NSLog(@"sorted the %d new items",[tweetsToProcess count]);
                if ([tweetsToProcess count] > 4)
                    for (int i=0; i < 4; i++)
                        NSLog(@"Item %d: %@", i, [(Tweet*)[tweetsToProcess objectAtIndex:i] tweetID]);
                e = [tweetsToProcess objectEnumerator];
                Tweet* theTweet = Nil;
                while ((theTweet = [e nextObject]) != Nil) {
                    if ([master theQueue] != Nil && NetworkAccessAllowed &&
                        [[theTweet hasBeenRead] boolValue] == NO) {
                        @try {
                            TweetOperation* top = [[TweetOperation alloc] initWithTweet:theTweet
                                                                                  index:Nil
                                                                   masterViewController:master
                                                                             replaceURL:Nil];
                            [TWLocMasterViewController incrementTasks];
                            [[master webQueue] addOperation:top];
                            [[master webQueue] setSuspended:NO];
                        } @catch (NSException *eee) {
                            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
                        }
                    }
                }
                NSLog(@"added %d TweetOperations",[tweetsToProcess count]);
                [[master updateQueue] addOperationWithBlock:^{
                    [master STATUS:[NSString stringWithFormat:@"%d tweets: %d images %0.2fMB",[[master idSet] count],[master numImages], [master sizeImages]/1024.0/1024.0]];
                }];
            } @catch (NSException *eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }
    } else {
        @try {
            // if no feed, and no subscription identity, we should go grab the subscriptions
            GoogleReader* reader = [master googleReader];
            NSArray* subscriptionArray = [reader getStreams];
            /*
             categories =     (
             {
             id = "user/08244464737233952669/label/red";
             label = red;
             }
             );
             firstitemmsec = 1348590243562;
             htmlUrl = "http://yummygingermen.tumblr.com/";
             id = "feed/http://yummygingermen.tumblr.com/rss";
             sortid = E9F15B75;
             title = "Yummy Ginger Men";
             */
            GoogleOperation* itemGetter = [[GoogleOperation alloc] initWithMaster:master rssFeed:nil orSubscriptions:subscriptionArray andStream:Nil];
            [TWLocMasterViewController incrementTasks];
            [[NSOperationQueue currentQueue] addOperation:itemGetter];
        } @catch (NSException *eee) {
            NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
        }
    }
    
    [TWLocMasterViewController decrementTasks];
    executing = NO; finished = YES;
}

- (NSUInteger)getItems:(NSString*)theID
{
    GoogleReader* reader = [master googleReader];
    NSArray* items = [reader unreadItems:theID];
    NSLog(@"item %@ contains %d items",theID,[items count]);
    
    NSEnumerator* e = [items objectEnumerator];
    NSDictionary* item;
    //googleAddedItems = [items count];
    googleAddedItems = 0;
    while ((item = [e nextObject]) != Nil &&
           googleAddedItems < 100) {
        googleAddedItems++;
        [self performSelectorOnMainThread:@selector(addItem:) withObject:item waitUntilDone:YES];
    }
    if (googleAddedItems > 0) {
        NSString* stat = [NSString stringWithFormat:@"Added %d items from %@",googleAddedItems,subscriptionName];
        [[master updateQueue] addOperationWithBlock:^{
            NSString* status = [[master.detailViewController activityLabel] text];
            [[master.detailViewController activityLabel] setText:[NSString stringWithFormat:@"%@\n%@",status,stat]];
            [master STATUS:stat];
        }];
    }
    return googleAddedItems;
/*
 (
 {
 alternate =     (
 {
 href = "http://dewittdailydoesit.tumblr.com/post/43229452343";
 type = "text/html";
 }
 );
 annotations =     (
 );
 categories =     (
 "user/08244464737233952669/label/tumblr",
 "user/08244464737233952669/state/com.google/reading-list",
 "user/08244464737233952669/state/com.google/fresh",
 cumshots
 );
 comments =     (
 );
 crawlTimeMsec = 1361028986087;
 id = "tag:google.com,2005:reader/item/370e36db6bbb2609";
 likingUsers =     (
 );
 origin =     {
 htmlUrl = "http://dewittdailydoesit.tumblr.com/";
 streamId = "feed/http://dewittdailydoesit.tumblr.com/rss";
 title = "I&#39;M DEWITT, MOTHERFUCKER.";
 };
 published = 1361028982;
 summary =     {
 content = "<img src=\"http://25.media.tumblr.com/tumblr_mde3g173561qe273do1_500.gif\"><br><br><p>This dick about to blo-ow-ow-ow-ow-ow-ow-ow-ow-ow.</p>";
 direction = ltr;
 };
 timestampUsec = 1361028986087925;
 title = "This dick about to blo-ow-ow-ow-ow-ow-ow-ow-ow-ow.";
 updated = 1361028982;
 }
 )

 */
}

- (void)addItem:(NSDictionary*)item
{
    @try {
        NSString* timestamp = [item objectForKey:@"timestampUsec"];
        NSString* username = subscriptionName;
        NSString* title = [item objectForKey:@"title"];
        NSDictionary* summary = [item objectForKey:@"summary"];
        NSString* contents = [summary objectForKey:@"content"];
        NSDictionary* origin = [item objectForKey:@"origin"];
        NSString* htmlURL = [origin objectForKey:@"htmlUrl"];
        NSString* streamID = [origin objectForKey:@"streamId"];
        NSArray* alternate = [item objectForKey:@"alternate"];
        if (alternate && [alternate count] > 0) {
            NSDictionary* altitem = [alternate objectAtIndex:0];
            htmlURL = [altitem objectForKey:@"href"];
            if ([alternate count] > 1)
                NSLog(@"choosing first item in alternate list %@", alternate);
        }
        NSString* googleID = [item objectForKey:@"id"];

        BOOL duplicate = NO;
        NSSet* dups = Nil;
        NSNumber* theID = [NSNumber numberWithLongLong:[timestamp longLongValue]];
        if (!duplicate) {
            dups = [[master idSet] objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                *stop = ([(NSNumber*)obj isEqualToNumber:theID]);
                return *stop;
            }];
            if (dups != Nil && [dups count] > 0)
                duplicate = YES;
        }
        if (duplicate) {
            NSLog(@"refusing duplicate %@ in %@",theID,username);
            googleAddedItems--;
            if (googleAddedItems < 0) googleAddedItems = 0;
            return;
        }

        //NSLog(@"adding item from %@: %@",username,title);
        NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[master.fetchedResultsController fetchRequest] entity];
        Tweet* tweet = [NSEntityDescription insertNewObjectForEntityForName:[entity name]
                                                     inManagedObjectContext:context];
        [tweet setSourceDict:[NSKeyedArchiver archivedDataWithRootObject:item]];
        [tweet setTweetID:theID];
        [tweet setFavorite:NO];
        [tweet setTimestamp:timestamp];
        [tweet setUsername:username];
        [tweet setTweet:[NSString stringWithFormat:@"%@\n%@",title,contents]];
        [tweet setLatitude:[NSNumber numberWithDouble:-900]];
        [tweet setLongitude:[NSNumber numberWithDouble:-900]];
        [tweet setUrl:htmlURL];
        [tweet setOrigURL:htmlURL];
        [tweet setOrigHTML:Nil];
        [tweet setLocationFromPic:[NSNumber numberWithBool:NO]];
        [tweet setHasBeenRead:[NSNumber numberWithBool:NO]];
        [tweet setListID:[NSNumber numberWithLongLong:0]];
        [tweet setFromGoogleReader:[NSNumber numberWithBool:YES]];
        [tweet setGoogleID:googleID];
        [tweet setGoogleStream:streamID];
        
        [tweetsToProcess addObject:tweet];
        [[master idSet] addObject:theID];
        [[master.fetchedResultsController managedObjectContext] processPendingChanges];
        [[master tableView] setNeedsLayout];
        [[master tableView] setNeedsDisplay];
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
@end
