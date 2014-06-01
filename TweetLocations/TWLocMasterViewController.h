//
//  TWLocMasterViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TWLocMasterViewController;
@class TWLocDetailViewController;

#import <CoreData/CoreData.h>
#import <Accounts/Accounts.h>
#import "Tweet.h"
#import "TMCache.h"

typedef void(^MasterCallback)(void);
typedef void(^MasterListsCallback)(NSDictionary* dict);

@interface TWLocMasterViewController : UITableViewController
        <NSFetchedResultsControllerDelegate,
         UIAlertViewDelegate>
{
    @public
    NSString* twitterAccountName;
    @private
    ACAccount* twitterAccount;
    
    NSDictionary* lists;
    NSMutableDictionary* maxIDEachList;
    NSMutableArray* queueGetArray;
    
    TMCache* imageServer;
    NSLock* imageLock;
}

@property (nonatomic, retain) NSString* tweetGroup;
@property (nonatomic)     long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

@property (strong, nonatomic) IBOutlet UILabel* statusLabel;
@property (strong, nonatomic) IBOutlet UILabel* queueLabel;
@property (nonatomic) BOOL tweetLibrary;
@property (atomic) BOOL getBestPicNext;

@property (strong, nonatomic) TWLocDetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *imageFetchController;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) id managedObjectContext;
@property (retain, nonatomic) UIImage* redX;
@property (retain, nonatomic) UIImage* pinImage;
@property (retain, nonatomic) UIImage* pinLinkImage;
@property (retain, nonatomic) UIImage* pinLinkPinImage;

@property (strong, nonatomic)     NSOperationQueue* singleOpQueue;
@property (strong, nonatomic)     NSOperationQueue* multipleOpQueue;
@property (strong, nonatomic)     NSOperationQueue* updateQueue;
@property (nonatomic, retain)     NSMutableSet* idSet;

@property (nonatomic, retain) NSMutableArray* prevTweets;

+ (void)incrementTasks;
+ (void)decrementTasks;
+ (int)numTasks;
+ (void)setNetworkAccessAllowed:(BOOL)allowed;
- (BOOL)openURL:(NSURL *)url;
- (void)killMax;

- (void)stowMinMaxIDs;

- (TMCache*)getImageServer;
- (void)clearImageMemoryCache;

- (NSData*)imageData:(NSString*)url;
- (void)imageData:(NSData*)data forURL:(NSString*)url;
- (void)backgroundImageData:(NSData*)data forURL:(NSString*)url;
- (void)deleteImageData:(NSString*)url;
- (void)keepTrackofReadURLs:(NSString*)url;
- (void)dropReadURLs:(MasterCallback)callback;
- (void)saveContext;
- (long long)sizeImages;
- (int)numImages;

#define SPECIAL_TWITTER_ACCOUNT_NAME @"curtsybear"
- (NSDictionary*)getTwitterLists:(BOOL)queueGets callback:(MasterListsCallback)callback;
- (NSDictionary*)specialGetTwitterLists:(BOOL)queueGets callback:(MasterListsCallback)callback;
- (void)addUser:(NSString*)twitterName toListSlug:(NSString*)listName inAccount:(NSString*)accountName;
- (void)removeUserFromAllLists:(NSString*)user;


- (void)nextTweet;
- (void)nextNewTweet;
- (void)prevTweet;
- (void)deleteTweet:(Tweet*)tweet;
- (void)refreshTweet:(Tweet*)tweet;
- (void)favoriteTweet:(Tweet*)tweet;
- (void)openInTwitter:(Tweet*)tweet;
- (int)unreadTweets;
- (Tweet*)tweetAtIndex:(int)index;

- (NSMutableDictionary*)scoringDictionary;
- (void)addScore:(NSInteger)addScore toName:(NSString*)username;
- (void)saveScores;
- (NSInteger)scoreForUser:(NSString*)username;

@end

@interface TweetOperation : NSOperation {
    TWLocMasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    NSString* replaceURL;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex masterViewController:(TWLocMasterViewController*)theMaster replaceURL:(NSString*)replace;
@end

@interface TweetImageOperation : NSOperation {
    TWLocMasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    NSString* replaceURL;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex masterViewController:(TWLocMasterViewController*)theMaster replaceURL:(NSString*)replace;
@end

@interface GetTweetOperation : NSOperation {
    TWLocMasterViewController* master;
    NSNumber* listID;
    BOOL executing, finished;
}
- (id)initWithMaster:(TWLocMasterViewController*)theMaster andList:(NSNumber*)theListID;

@end
@interface StoreTweetOperation : NSOperation {
    TWLocMasterViewController* master;
    NSNumber* listID;
    BOOL executing, finished;
    NSArray* timeline;
}
- (id)initWithMaster:(TWLocMasterViewController*)theMaster timeline:(NSArray*)theTimeline andList:(NSNumber*)theListID;

@end
