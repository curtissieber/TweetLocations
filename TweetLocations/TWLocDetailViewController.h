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
            <UISplitViewControllerDelegate, UIScrollViewDelegate, UIAlertViewDelegate,
            UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegate,
            UITextViewDelegate>
{
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
@property (strong, nonatomic) IBOutlet UITextView* activityLabel;
@property (strong, nonatomic) IBOutlet UILabel* labelOverEverything;

@property (retain, nonatomic) TWLocMasterViewController* master;

@property (retain, nonatomic) IBOutlet UIButton* infoButton;
@property (retain, nonatomic) IBOutlet UIButton* videoButton;
@property (retain, nonatomic) IBOutlet UIButton* previewVideoButton;
@property (retain, nonatomic) IBOutlet UIButton* picButton;
@property (retain, nonatomic) IBOutlet UICollectionView* picCollection;
@property (retain, nonatomic) NSArray *pictures;

+ (BOOL)imageExtension:(NSString*)urlStr;
+ (NSMutableArray*)staticGetURLs:(NSString*)html;
+ (NSString*)staticFindJPG:(NSString*)html theUrlStr:(NSString*)url;
- (BOOL)openURL:(NSURL *)url;
- (IBAction)touchedStatus:(id)sender;
- (IBAction)picturesButtonHit:(id)sender;
- (IBAction)videoButtonHit:(id)sender;
- (IBAction)previewVideoButtonHit:(id)sender;
- (IBAction)infoButtonHit:(id)sender;
@end
