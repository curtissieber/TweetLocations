//
//  TWLocDetailViewController.h
//  TweetLocations
//
//  Created by Curtis Sieber on 8/25/12.
//  Copyright (c) 2012 Curtsybear.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "TWLocMasterViewController.h"
#import "Tweet.h"

@interface TWLocDetailViewController : UIViewController
            <UISplitViewControllerDelegate, UIScrollViewDelegate, UIAlertViewDelegate> {
                NSData* thisImageData;
}

@property (strong, nonatomic) Tweet* detailItem;

@property (retain, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (retain, nonatomic) IBOutlet MKMapView *mapView;
@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet UILabel *bigLabel;
@property (retain, nonatomic) IBOutlet UITextView *textView;
@property (retain, nonatomic) IBOutlet UIButton *sizeButton;

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView* activityView;

@property (retain, nonatomic) TWLocMasterViewController* master;

+ (BOOL)imageExtension:(NSString*)urlStr;
+ (NSMutableArray*)staticGetURLs:(NSString*)html;
+ (NSString*)staticFindJPG:(NSString*)html theUrlStr:(NSString*)url;
- (BOOL)openURL:(NSURL *)url;
@end
