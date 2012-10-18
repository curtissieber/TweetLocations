//
//  TWLocMasterViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TWLocDetailViewController;

#import <CoreData/CoreData.h>
#import <Accounts/Accounts.h>
#import "Tweet.h"

@interface TWLocMasterViewController : UITableViewController
        <NSFetchedResultsControllerDelegate,
         UIAlertViewDelegate>
{
    NSString* twitterAccountName;
    ACAccount* twitterAccount;
    long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;
    NSMutableDictionary* imageDict;
    NSLock* imageDictLock;
}

@property (nonatomic)     long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

@property (strong, nonatomic) IBOutlet UILabel* statusLabel;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView* activityView;

@property (strong, nonatomic) TWLocDetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (retain, nonatomic) UIImage* redX;
@property (retain, nonatomic) UIImage* pinImage;
@property (retain, nonatomic) UIImage* pinLinkImage;
@property (retain, nonatomic) UIImage* pinLinkPinImage;

@property (strong, nonatomic)     NSOperationQueue* theQueue;
@property (nonatomic, retain)     NSMutableSet* idSet;
@property (nonatomic, retain)     NSMutableDictionary* tweetText;

+ (void)setNetworkAccessAllowed:(BOOL)allowed;
- (BOOL)openURL:(NSURL *)url;
- (void)killMax;
- (NSData*)imageData:(NSString*)url;
- (void)imageData:(NSData*)data forURL:(NSString*)url;
- (void)nextTweet;
- (void)prevTweet;
- (void)deleteTweet:(Tweet*)tweet;
- (void)refreshTweet:(Tweet*)tweet;
- (void)favoriteTweet:(Tweet*)tweet;
@end

@interface TweetOperation : NSOperation {
    TWLocMasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
masterViewController:(TWLocMasterViewController*)theMaster;
@end

@interface TweetImageOperation : NSOperation {
    TWLocMasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
masterViewController:(TWLocMasterViewController*)theMaster;
@end

@interface GetTweetOperation : NSOperation {
    TWLocMasterViewController* master;
    BOOL executing, finished;
}
- (id)initWithMaster:(TWLocMasterViewController*)theMaster;

@end
@interface StoreTweetOperation : NSOperation {
    TWLocMasterViewController* master;
    BOOL executing, finished;
    NSArray* timeline;
}
- (id)initWithMaster:(TWLocMasterViewController*)theMaster timeline:(NSArray*)theTimeline;

@end
