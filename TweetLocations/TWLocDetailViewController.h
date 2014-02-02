//
//  TWLocDetailViewController.h
//  
//
//  Created by Curtis Sieber on 1/26/14.
//
//

#import <UIKit/UIKit.h>
#import "TWLocMasterViewController.h"
#import "Tweet.h"

typedef void(^mainBlockToDo)(void);

@interface TWLocDetailViewController : UIViewController <UISplitViewControllerDelegate>
@property (strong, nonatomic) Tweet* detailItem;
@property (retain, nonatomic) TWLocMasterViewController* master;

@property (strong, nonatomic) IBOutlet UILabel* labelOverEverything;

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView* activityView;
@property (strong, nonatomic) IBOutlet UITextView* activityLabel;

- (BOOL)openURL:(NSURL *)url;
+ (NSMutableArray*)staticGetURLs:(NSString*)html;
+ (BOOL)isVideoFileURL:(NSString*)url;
+ (BOOL)imageExtension:(NSString*)urlStr;
+ (NSString*)staticFindJPG:(NSString*)html theUrlStr:(NSString*)url;
- (void)doMainBlock:(mainBlockToDo)block;

@end
