//
//  TWLoc2MasterViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TWLoc2DetailViewController;

#import <CoreData/CoreData.h>
#import <Accounts/Accounts.h>
#import "Tweet.h"

@interface TWLoc2MasterViewController : UITableViewController
        <NSFetchedResultsControllerDelegate,
         UIAlertViewDelegate>
{
    NSMutableDictionary* imageDict;
    NSLock* imageDictLock;
    NSString* twitterAccountName;
    ACAccount* twitterAccount;
    //long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;
    
    NSDictionary* lists;
    NSMutableDictionary* maxIDEachList;
    NSMutableArray* queueGetArray;
}

@property (nonatomic, retain) NSString* tweetGroup;
@property (nonatomic)     long long twitterIDMax, twitterIDMin, nextIDMax, maxTweetsToGet;

@property (strong, nonatomic) IBOutlet UILabel* statusLabel;
@property (strong, nonatomic) IBOutlet UILabel* queueLabel;
@property (nonatomic) BOOL tweetLibrary;
@property (nonatomic) BOOL googleReaderLibrary;

@property (strong, nonatomic) TWLoc2DetailViewController *detailViewController;

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
    TWLoc2MasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
masterViewController:(TWLoc2MasterViewController*)theMaster;
@end

@interface TweetImageOperation : NSOperation {
    TWLoc2MasterViewController* master;
    Tweet* tweet;
    NSIndexPath* index;
    BOOL executing, finished;
}
- (id)initWithTweet:(Tweet*)theTweet index:(NSIndexPath*)theIndex
masterViewController:(TWLoc2MasterViewController*)theMaster;
@end

@interface GetTweetOperation : NSOperation {
    TWLoc2MasterViewController* master;
    NSNumber* listID;
    BOOL executing, finished;
}
- (id)initWithMaster:(TWLoc2MasterViewController*)theMaster andList:(NSNumber*)theListID;

@end
@interface StoreTweetOperation : NSOperation {
    TWLoc2MasterViewController* master;
    NSNumber* listID;
    BOOL executing, finished;
    NSArray* timeline;
}
- (id)initWithMaster:(TWLoc2MasterViewController*)theMaster timeline:(NSArray*)theTimeline andList:(NSNumber*)theListID;

@end
