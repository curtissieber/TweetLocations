//
//  TWLocMasterViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleReader.h"

@class TWLocDetailViewController;

#import <CoreData/CoreData.h>
#import <Accounts/Accounts.h>
#import "Tweet.h"
#import "TWLocImages.h"
#import "TWFastImages.h"

// TWLocImages is the old, good one
// TWFastImages is the new one I'm trying out
#define TWIMAGE TWLocImages

typedef void(^MasterCallback)(void);

@interface TWLocMasterViewController : UITableViewController
        <NSFetchedResultsControllerDelegate,
         UIAlertViewDelegate>
{
    NSString* twitterAccountName;
    ACAccount* twitterAccount;
    //long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;
    
    NSDictionary* lists;
    NSMutableDictionary* maxIDEachList;
    NSMutableArray* queueGetArray;
    
    TWIMAGE* imageServer;
}

@property (nonatomic, retain) NSString* tweetGroup;
@property (nonatomic)     long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

@property (strong, nonatomic) IBOutlet UILabel* statusLabel;
@property (strong, nonatomic) IBOutlet UILabel* queueLabel;
@property (nonatomic) BOOL tweetLibrary;
@property (nonatomic) BOOL googleReaderLibrary;

@property (strong, nonatomic) TWLocDetailViewController *detailViewController;
@property (retain, nonatomic) GoogleReader* googleReader;

@property (strong, nonatomic) NSFetchedResultsController *imageFetchController;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) id managedObjectContext;
@property (retain, nonatomic) UIImage* redX;
@property (retain, nonatomic) UIImage* pinImage;
@property (retain, nonatomic) UIImage* pinLinkImage;
@property (retain, nonatomic) UIImage* pinLinkPinImage;

@property (strong, nonatomic)     NSOperationQueue* theQueue;
@property (strong, nonatomic)     NSOperationQueue* theOtherQueue;
@property (strong, nonatomic)     NSOperationQueue* webQueue;
@property (strong, nonatomic)     NSOperationQueue* updateQueue;
@property (nonatomic, retain)     NSMutableSet* idSet;
@property (nonatomic, retain)     NSMutableDictionary* tweetText;

+ (void)incrementTasks;
+ (void)decrementTasks;
+ (int)numTasks;
+ (void)setNetworkAccessAllowed:(BOOL)allowed;
- (BOOL)openURL:(NSURL *)url;
- (void)killMax;
- (TWIMAGE*)getImageServer;
- (NSData*)imageData:(NSString*)url;
- (void)imageData:(NSData*)data forURL:(NSString*)url;
- (void)deleteImageData:(NSString*)url;
- (void)keepTrackofReadURLs:(NSString*)url;
- (void)dropReadURLs:(MasterCallback)callback;
- (void)nextTweet;
- (void)nextNewTweet;
- (void)prevTweet;
- (void)deleteTweet:(Tweet*)tweet;
- (void)refreshTweet:(Tweet*)tweet;
- (void)favoriteTweet:(Tweet*)tweet;
- (int)unreadTweets;
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
@interface GoogleOperation : NSOperation {
    TWLocMasterViewController* master;
    NSArray* subscriptions;
    NSString* subscriptionName;
    NSString* streamName;
    BOOL executing, finished;
    NSArray* rssFeed;
    NSMutableArray* tweetsToProcess;
}
- (id)initWithMaster:(TWLocMasterViewController*)theMaster rssFeed:(NSArray*)theFeed orSubscriptions:(NSArray*)theSubscriptions andStream:(NSString*)theStreamName;

@end
