//
//  TWLocMasterViewController.m
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import "TWLocMasterViewController.h"

#import "TWLocDetailViewController.h"

#import <Accounts/Accounts.h>
#import <Twitter/Twitter.h>
#import <ImageIO/ImageIO.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "Tweet.h"
#import "URLFetcher.h"
#import <CoreData/NSFetchedResultsController.h>

@interface TWLocMasterViewController ()
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation TWLocMasterViewController
@synthesize twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

#define ALERT_DUMMY (1)
#define ALERT_NOTWITTER (666)
#define ALERT_SELECTACCOUNT (1776)

static int queuedTasks = 0;

#pragma mark image

- (void)STATUS:(NSString*)thestatus
{
    NSLog(@"%@",thestatus);
    [_statusLabel setText:thestatus];
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

- (void)killMax { twitterIDMax = twitterIDMin = -1; }

- (NSData*)imageData:(NSString*)url
{
    @try {
        NSData* data = Nil;
        [self->imageDictLock lock];
        data = [self->imageDict objectForKey:url];
        [self->imageDictLock unlock];
        return data;
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
    return Nil;
}

- (void)imageData:(NSData*)data forURL:(NSString*)url
{
    @try {
        [self->imageDictLock lock];
        if (data != Nil && url != Nil) {
            if ([imageDict objectForKey:url] == Nil) {
                [self->imageDict setObject:data forKey:url];
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

- (void)nextTweet
{
    @try {
        NSLog(@"NEXT TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        int numRows = [self.tableView numberOfRowsInSection:selected.section];
        if (selected.row+1 >= numRows)
            return;
        NSIndexPath* nextindex = [NSIndexPath indexPathForRow:selected.row+1
                                                    inSection:selected.section];
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
        self.detailViewController.detailItem = object;
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)prevTweet
{
    @try {
        NSLog(@"PREV TWEET");
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        if (selected.row-1 < 0)
            return;
        NSIndexPath* nextindex = [NSIndexPath indexPathForRow:selected.row-1
                                                    inSection:selected.section];
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
        self.detailViewController.detailItem = object;
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
        [context deleteObject:tweet];
        [context processPendingChanges];
        [self.tableView reloadData];
        
        NSIndexPath* nextindex = [NSIndexPath indexPathForRow:selected.row + offset
                                                    inSection:selected.section];
        [self.tableView selectRowAtIndexPath:nextindex
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:nextindex];
        self.detailViewController.detailItem = object;
        
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}
- (void)refreshTweet:(Tweet*)tweet
{
    NSLog(@"want to refresh tweet %@ %@",[tweet tweetID], [tweet url]);
    
    @try {
        //[tweet setOrigHTML:Nil];
        if ([tweet origURL] != Nil)
            [tweet setUrl:[tweet origURL]];
        else {
            NSArray* urls = [TWLocDetailViewController staticGetURLs:[tweet tweet]];
            if ([urls count] > 0)
                [tweet setUrl:[urls objectAtIndex:0]];
        }
        NSLog(@"refresh gives url %@",[tweet url]);
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context processPendingChanges];
        NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
        
        [self.tableView selectRowAtIndexPath:selected
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:selected];
        self.detailViewController.detailItem = object;
        [self.detailViewController setDetailItem:tweet];
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
             [tweet setFavorite:[NSNumber numberWithBool:YES]];
             NSIndexPath* selected = [self.tableView indexPathForSelectedRow];
             NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
             [context processPendingChanges];
             UITableViewCell* cell =[self.tableView cellForRowAtIndexPath:selected];
             [cell setNeedsDisplay];
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
                 [self STATUS:@"Request to access account error"];
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
            
            if (_theQueue) {
                maxTweetsToGet = NUMTWEETSTOGET;
                GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self];
                [_theQueue setSuspended:NO];
                queuedTasks++;  [_activityView startAnimating];
                [_theQueue addOperation:getTweetOp];
            }
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
        }
        if ([alertView tag] == ALERT_SELECTACCOUNT) {
            NSString* accountName = [alertView buttonTitleAtIndex:buttonIndex];
            NSLog(@"Selected %@ twitter account", accountName);
            if ([accountName compare:@"CANCEL"] != NSOrderedSame) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:accountName forKey:@"twitterAccount"];
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
                
                if (_theQueue) {
                    maxTweetsToGet = NUMTWEETSTOGET;
                    GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self];
                    [_theQueue setSuspended:NO];
                    queuedTasks++;  [_activityView startAnimating];
                    [_theQueue addOperation:getTweetOp];
                }
                
            }
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }

}

#pragma mark Tweets
#define MAXTWEETS (2000)

- (void)getTweets
{
    if (self->twitterAccount == Nil)
        return;
    
    @try {
        
        // Now make an authenticated request to our endpoint
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:@"1" forKey:@"include_entities"];
        if (twitterIDMax > 0)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",twitterIDMax] forKey:@"since_id"];
        [params setObject:@"50" forKey:@"count"];
        if (twitterIDMin > 0 && twitterIDMin != twitterIDMax)
            [params setObject:[[NSString alloc] initWithFormat:@"%lld",twitterIDMin] forKey:@"max_id"];
        
        //  The endpoint that we wish to call
        NSURL *url =
        [NSURL
         URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
        
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        //  Build the request with our parameter
        TWRequest *request =[[TWRequest alloc] initWithURL:url
                                                parameters:params
                                             requestMethod:TWRequestMethodGET];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
        
        // Attach the account object to this request
        [request setAccount:self->twitterAccount];
        
        NSLog(@"getting tweets max=%lld min=%lld", twitterIDMax, twitterIDMin);
        [self STATUS:@"Requesting tweets"];
        
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
                     [self STATUS:@"Storing tweets"];
                     //[self storeTweets:timeline];
                     if (_theQueue != Nil) {
                         NSLog(@"adding storetweet size=%d to the Queue", [timeline count]);
                         StoreTweetOperation* storeTweetOp = [[StoreTweetOperation alloc] initWithMaster:self timeline:timeline];
                         [_theQueue setSuspended:NO];
                         queuedTasks++;  [_activityView startAnimating];
                         [_theQueue addOperation:storeTweetOp];
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

- (void)storeTweets:(NSArray*)timeline 
{
    @try {
        int storedTweets = 0;
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
        
        NSEnumerator* e = [timeline objectEnumerator];
        NSDictionary* item;
        
        NSLog(@"storing %d tweets",[timeline count]);
        while ((item = [e nextObject]) != Nil) {
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
                        NSDictionary* urls = [urlsArray objectAtIndex:0];
                        if (urls != Nil) {
                            theUrl = [urls objectForKey:@"expanded_url"];
                            //NSLog(@"   url=%@",theUrl);
                        }
                    }
                    NSArray* media = [entities objectForKey:@"media"];
                    if (media != Nil && [media count] > 0) {
                        NSDictionary* mediaItem = [media objectAtIndex:0];
                        if (mediaItem != Nil) {
                            NSString* anotherURL = [mediaItem objectForKey:@"media_url"];
                            if (anotherURL != Nil && [anotherURL length] > 4) {
                                theUrl = anotherURL;
                                //NSLog(@"   url=%@",theUrl);
                            }
                        }
                    }
                }
                
                BOOL duplicate = NO;
                if (([theID longLongValue] == twitterIDMin) ||
                    ([theID longLongValue] == twitterIDMax))
                    duplicate = YES;
                
                if ([theID longLongValue] > nextIDMax) {
                    nextIDMax = [theID longLongValue];
                }
                if ([theID longLongValue] < twitterIDMin ||
                    twitterIDMin <= 0) {
                    twitterIDMin = [theID longLongValue];
                }
                NSSet* dups = Nil;
                if (!duplicate) {
                    long long longID = [theID longLongValue];
                    dups = [_idSet objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                        *stop = ([(NSNumber*)obj longLongValue] == longID);
                        return *stop;
                    }];
                    if (dups != Nil && [dups count] > 0)
                        duplicate = YES;
                }
                Tweet *tweet = Nil;
                if (!duplicate) {
                    //NSLog(@"New tweet %@",theID);
                    if ([theUrl length] > 4) {
                        tweet = [NSEntityDescription insertNewObjectForEntityForName:[entity name]
                                                              inManagedObjectContext:context];
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
                    }
                    [_idSet addObject:theID];
                    storedTweets++;
                } else {
                    NSLog(@"DUP tweet %@",theID);
                    //maxTweetsToGet = -1;
                    //tweet = [results objectAtIndex:0];
                }
                
            } @catch (NSException* eee) {
                NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
            }
        }
        NSLog(@"Done storing %d tweets (%d real tweets)",[timeline count], storedTweets);
        
        maxTweetsToGet -= [timeline count];
        NSLog(@"got %d tweets, %lld more to get", [timeline count], maxTweetsToGet);
        if (([timeline count] < 5 || maxTweetsToGet < 1 || storedTweets == 0) &&
            nextIDMax > 0)
            twitterIDMax = nextIDMax;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[[NSString alloc]initWithFormat:@"%lld",twitterIDMax] forKey:@"twitterIDMax"];
        if ([timeline count] > 0 && storedTweets > 0)
            [defaults setObject:[[NSString alloc]initWithFormat:@"%lld",twitterIDMin] forKey:@"twitterIDMin"];
        [defaults synchronize];
        
        if (_theQueue != Nil && storedTweets > 0 &&
            !([timeline count] < 5 || maxTweetsToGet < 1)) {
            NSLog(@"adding another getTweet to the Queue");
            GetTweetOperation* getTweetOp = [[GetTweetOperation alloc] initWithMaster:self];
            [_theQueue setSuspended:NO];
            queuedTasks++;  [_activityView startAnimating];
            [_theQueue addOperation:getTweetOp];
        } else {
            [_theQueue addOperationWithBlock:^{
                [self checkForMaxTweets];
            }];
        }
    } @catch (NSException *eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)noTwitterAlert
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"No Twitter Accounts"
                                                    message:@"A twitter account must to be set up in the Settings for this device, and access must be allowed for this application"
                                                   delegate:self
                                          cancelButtonTitle:@"Understood, EXIT"
                                          otherButtonTitles: nil];
    [alert setTag:ALERT_NOTWITTER];
    [alert show];
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    //self.navigationItem.leftBarButtonItem = self.editButtonItem;

    /*UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;*/
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                      target:self
                                      action:@selector(refreshTweets:)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    UIBarButtonItem *setAllReadButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                      target:self
                                      action:@selector(setAllRead:)];
    self.navigationItem.leftBarButtonItem = setAllReadButton;
    self.detailViewController = (TWLocDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    [self.detailViewController setMaster:self];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"LocPin" ofType:@"png"];
    self.pinImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"LocPinLink" ofType:@"png"];
    self.pinLinkImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"LocPinLinkGreen" ofType:@"png"];
    self.pinLinkPinImage = [[UIImage alloc] initWithContentsOfFile:filePath];
    filePath = [[NSBundle mainBundle] pathForResource:@"redX" ofType:@"png"];
    self.redX = [[UIImage alloc] initWithContentsOfFile:filePath];
    
    queuedTasks = 0;
    _theQueue = [[NSOperationQueue alloc] init];
    [_theQueue setMaxConcurrentOperationCount:1];
    self->imageDictLock = [[NSLock alloc] init];
    self->imageDict = [[NSMutableDictionary alloc] init];
    
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
    
    self->twitterAccount = Nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self->twitterAccountName = [defaults objectForKey:@"twitterAccount"];
    self->twitterIDMax = [(NSString*)[defaults objectForKey:@"twitterIDMax"] longLongValue];
    //self->twitterIDMin = [(NSString*)[defaults objectForKey:@"twitterIDMin"] longLongValue];
    self->twitterIDMin = -1; // for the grab, make certain to grab it all
    [self getTwitterAccount];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    @try {
        NSLog(@"MEMORY WARNING in master view");
        [self->imageDictLock lock];
        [imageDict removeAllObjects];
        NSLog(@"MEMORY WARNING releasing ALL IMAGES");
        [self->imageDictLock unlock];
    } @catch (NSException *eee) {
        [self->imageDictLock unlock];
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }
}

- (void)setAllRead:(id)sender
{
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
        [tweet setHasBeenRead:[NSNumber numberWithBool:YES]];
    }
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
}

- (void)refreshTweets:(id)sender
{
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

    maxTweetsToGet = 800;
    [self getTweets];
}

- (void)checkForMaxTweets
{
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSArray* sections = [self.fetchedResultsController sections];
    id<NSFetchedResultsSectionInfo> section = [sections objectAtIndex:0];
    int rows = [section numberOfObjects];
    NSLog(@"sections=%d row[0]=%d",[sections count],rows);
    if (rows > MAXTWEETS) {
        NSLog(@"More than %d tweets, going to remove some", MAXTWEETS);
        for (int i = rows-1; i > MAXTWEETS; i--) {
            NSIndexPath* indexPath = [NSIndexPath indexPathForItem:i inSection:0];
            Tweet *tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if ([[tweet locationFromPic] boolValue] == NO &&
                [[tweet favorite] boolValue] == NO &&
                [[tweet hasBeenRead] boolValue] == YES) {
                //NSLog(@"removing %d tweet %@",i,tweet);
                [context deleteObject:tweet];
            }
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [context processPendingChanges];
        [self.tableView reloadData];
        NSString* status = [[NSString alloc] initWithFormat: @"Tweet Count = %d", [self.tableView numberOfRowsInSection:0]];
        [self STATUS:status];

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

- (void)insertNewObject:(id)sender
{
    return;
/*
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
         // Replace this implementation with code to handle the error appropriately.
         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
*/
 }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

/*
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}*/

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
    /*[[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Save the context.  But I keep having the queue stop dead at this point BOO
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSError *error = [[NSError alloc] init];
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error saving the context %@, %@", error, [error userInfo]);
        }
        NSLog(@"Got a chance to save, YAY!");
    }];*/
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*@try {
        Tweet* tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
        UIFont* f = [UIFont boldSystemFontOfSize:14];
        NSString* text = [NSString stringWithFormat:@"[%@] %@", [tweet username], [tweet tweet]];
        CGSize tablesize = [self tableView].frame.size;
        CGFloat size = [text sizeWithFont:f constrainedToSize:tablesize].height;
        if ([tweet url] != Nil)
            size += 15;
        size += 11;
        
        double latitude = [[tweet latitude] doubleValue];
        double longitude = [[tweet longitude] doubleValue];
        if (latitude > -900 && longitude > -900) {
            size += [f lineHeight];
        }
        
        return size;
    } @catch (NSException* eee) {
        NSLog(@"Exception %@ %@", [eee description], [eee callStackSymbols]);
    }*/
    return 80;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Tweet *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [object setHasBeenRead:[NSNumber numberWithBool:YES]];
        [[segue destinationViewController] setDetailItem:object];
        self.detailViewController = [segue destinationViewController];
        [self.detailViewController setMaster:self];
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
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

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Tweet" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"tweetID" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    _idSet = [[NSMutableSet alloc] initWithCapacity:100];
    
    if ([self.fetchedResultsController fetchedObjects] != Nil) {
        NSLog(@"Initital FETCH is %d tweets",[[self.fetchedResultsController fetchedObjects] count]);
        NSEnumerator* e = [[self.fetchedResultsController fetchedObjects] objectEnumerator];
        Tweet* tweet;
        while ((tweet = [e nextObject]) != Nil)
            [_idSet addObject:[tweet tweetID]];
        NSLog(@"done setting up the ID array");
    } else NSLog(@"NO TWEETS FETCHED! IS THE DB EMPTY?");
    
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
    Tweet *tweet = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    [self cellSetup:cell forTweet:tweet];
    
    if (_theQueue != Nil && NetworkAccessAllowed &&
            [[tweet hasBeenRead] boolValue] == NO) {
        TweetOperation* top = [[TweetOperation alloc] initWithTweet:tweet
                                                              index:indexPath
                                               masterViewController:self];
        queuedTasks++;  [_activityView startAnimating];
        [_theQueue addOperation:top];
        [_theQueue setSuspended:NO];
    }
}

- (void)cellSetup:(UITableViewCell *)cell forTweet:(Tweet*)tweet
{
    if (cell == Nil || tweet == Nil)
        return;
    
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
    [cell setFrame:cellFrame];
    [cell setTag:cellFrame.size.height];
    
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
        [cell.contentView setBackgroundColor:[UIColor cyanColor]];
        [cell.textLabel setBackgroundColor:[UIColor cyanColor]];
        [cell.detailTextLabel setBackgroundColor:[UIColor cyanColor]];
    } else if ([[tweet hasBeenRead] boolValue] == YES) {
        [cell.contentView setBackgroundColor:[UIColor lightGrayColor]];
        [cell.textLabel setBackgroundColor:[UIColor lightGrayColor]];
        [cell.detailTextLabel setBackgroundColor:[UIColor lightGrayColor]];
    } else {
        [cell.contentView setBackgroundColor:[UIColor clearColor]];
        [cell.textLabel setBackgroundColor:[UIColor clearColor]];
        [cell.detailTextLabel setBackgroundColor:[UIColor clearColor]];
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
}

@end

@implementation TweetOperation

- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
            masterViewController:(TWLocMasterViewController*)theMaster
{
    self = [super init];
    executing = finished = NO;
    self->index = theIndex;
    self->tweet = theTweet;
    self->master = theMaster;
    [self setQueuePriority:NSOperationQueuePriorityLow];
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
                                                                masterViewController:self->master];
    NSOperationQueue* queue = [NSOperationQueue currentQueue];
    queuedTasks++;  [[self->master activityView] startAnimating];
    [queue addOperation:imageOperation];
}

- (void)main
{
    executing = YES;

    if (([tweet url] == Nil) ||
        ([[tweet url] length] < 4) ||
        ([master imageData:[tweet url]] != Nil) ) {
        executing = NO; finished = YES;
        return;
    }
    if ([TWLocDetailViewController imageExtension:[tweet url]]) {
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
            executing = NO; finished = YES;
            return;
        }
        NSMutableString* html = [[NSMutableString alloc] initWithData:data
                                                  encoding:NSStringEncodingConversionAllowLossy];
        if (html != Nil) {
            NSString* replace = [TWLocDetailViewController staticFindJPG:html theUrlStr:[tweet url]];
            //[tweet setOrigHTML:html];
            if (replace != Nil) {
                [tweet setUrl:replace];
                NSLog(@"URL_REPLACE %@",replace);
                if ([TWLocDetailViewController imageExtension:[tweet url]])
                    [self tryImage];
                [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
            }
        }
    }

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
        [context processPendingChanges];
    }];

    if (--queuedTasks == 0)
        [[self->master activityView] stopAnimating];
    executing = NO; finished = YES;
}

@end

@implementation TweetImageOperation

- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
masterViewController:(TWLocMasterViewController*)theMaster
{
    self = [super init];
    executing = finished = NO;
    self->index = theIndex;
    self->tweet = theTweet;
    self->master = theMaster;
    [self setQueuePriority:NSOperationQueuePriorityVeryLow];
    return self;
}

- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)tryImage
{
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:[tweet url]]
                                             cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                         timeoutInterval:30];
    NSURLResponse* response=nil;
    NSError* error=nil;
    NSData* imageData=[NSURLConnection sendSynchronousRequest:request
                                            returningResponse:&response
                                                        error:&error];
    if (imageData == Nil) {
        NSLog(@"BAD IMAGE CONNECTION to %@",[tweet url]);
        return;
    } else {
        NSLog(@"background imagedata size %d %@",[imageData length],[tweet url]);
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
        [tweet setLocationFromPic:[NSNumber numberWithBool:YES]];
        [tweet setLatitude:[NSNumber numberWithDouble:lat]];
        [tweet setLongitude:[NSNumber numberWithDouble:lon]];
        NSLog(@" @ %0.1f,%01f",lat,lon);
        [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
    }
    [master imageData:imageData forURL:[tweet url]];
}

- (void)main
{
    executing = YES;
    
    if (([tweet url] == Nil) ||
        ([[tweet url] length] < 4) ||
        ([master imageData:[tweet url]] != Nil) ) {
        executing = NO; finished = YES;
        return;
    }
    if ([TWLocDetailViewController imageExtension:[tweet url]]) {
        [self tryImage];
        [master cellSetup:[[master tableView] cellForRowAtIndexPath:index] forTweet:tweet];
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSManagedObjectContext *context = [master.fetchedResultsController managedObjectContext];
        [context processPendingChanges];
    }];
    
    if (--queuedTasks == 0)
        [[self->master activityView] stopAnimating];
    executing = NO; finished = YES;
}

@end

@implementation GetTweetOperation

- (id)initWithMaster:(TWLocMasterViewController*)theMaster
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    [self setQueuePriority:NSOperationQueuePriorityNormal];
    return self;
}

- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    [master setNextIDMax:-1];
    [master getTweets];
    if (--queuedTasks == 0)
        [[self->master activityView] stopAnimating];
    executing = NO; finished = YES;
}

@end

@implementation StoreTweetOperation

- (id)initWithMaster:(TWLocMasterViewController*)theMaster timeline:(NSArray*)theTimeline
{
    self = [super init];
    executing = finished = NO;
    master = theMaster;
    timeline = theTimeline;
    [self setQueuePriority:NSOperationQueuePriorityNormal];
    return self;
}
- (BOOL)isReady { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)main
{
    executing = YES;
    [master storeTweets:timeline];
    if (--queuedTasks == 0)
        [[self->master activityView] stopAnimating];
    executing = NO; finished = YES;
}


@end